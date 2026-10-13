#include "taskbar_protocol.h"
#include <cstdio>
#include <string>
#include <vector>
int wmain(int argc, wchar_t** argv) {
  if (argc != 2 && argc != 3) return 2;
  SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
  HANDLE input = nullptr, input_writer = nullptr, output = nullptr, output_writer = nullptr, parent = nullptr;
  if (!CreatePipe(&input, &input_writer, &security, 65536) ||
      !CreatePipe(&output, &output_writer, &security, 65536) ||
      !DuplicateHandle(GetCurrentProcess(), GetCurrentProcess(), GetCurrentProcess(), &parent,
                       SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, TRUE, 0)) return 2;
  SetHandleInformation(input_writer, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(output, HANDLE_FLAG_INHERIT, 0);
  HANDLE inherited[] = {input, output_writer, parent};
  SIZE_T size = 0; InitializeProcThreadAttributeList(nullptr, 1, 0, &size);
  std::vector<uint8_t> attributes(size);
  STARTUPINFOEXW startup{}; startup.StartupInfo.cb = sizeof(startup);
  startup.lpAttributeList = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(attributes.data());
  if (!InitializeProcThreadAttributeList(startup.lpAttributeList, 1, 0, &size) ||
      !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
                                inherited, sizeof(inherited), nullptr, nullptr)) return 2;
  std::wstring command = L"\"" + std::wstring(argv[1]) + L"\" " +
      std::to_wstring(reinterpret_cast<uintptr_t>(input)) + L" " +
      std::to_wstring(reinterpret_cast<uintptr_t>(output_writer)) + L" " +
      std::to_wstring(reinterpret_cast<uintptr_t>(parent));
  PROCESS_INFORMATION process{};
  BOOL launched = CreateProcessW(argv[1], command.data(), nullptr, nullptr, TRUE,
                                CREATE_NO_WINDOW | EXTENDED_STARTUPINFO_PRESENT,
                                nullptr, nullptr, &startup.StartupInfo, &process);
  DeleteProcThreadAttributeList(startup.lpAttributeList);
  CloseHandle(input); CloseHandle(output_writer); CloseHandle(parent);
  if (!launched) return 2;
  CloseHandle(process.hThread);
  if (argc == 3) {
    // A status packet is valid framing but illegal in the parent-to-helper direction.
    bool written = taskbar::WritePacket(input_writer, taskbar::PacketType::status, taskbar::EncodeCode(1));
    bool refused = written && WaitForSingleObject(process.hProcess, 3000) == WAIT_OBJECT_0;
    std::printf("%s wrong-direction IPC tears down helper\n", refused ? "PASS" : "FAIL");
    if (!refused) TerminateProcess(process.hProcess, 7);
    CloseHandle(input_writer); CloseHandle(output); CloseHandle(process.hProcess);
    return refused ? 0 : 1;
  }
  TaskbarFrame frame; frame.cells = {{L"CPU 25%", 0xFFFFFFFF, L"CPU usage"}};
  std::vector<uint8_t> payload;
  bool ok = taskbar::EncodeFrame(frame, &payload) && taskbar::WritePacket(input_writer, taskbar::PacketType::frame, payload);
  bool displayed = false, disabled = false;
  std::vector<uint8_t> buffer;
  auto deadline = GetTickCount64() + 4000;
  while (ok && GetTickCount64() < deadline && !displayed) {
    std::vector<taskbar::Packet> packets;
    ok = taskbar::ReadPipeAvailable(output, &buffer, &packets);
    for (const auto& packet : packets) {
      uint32_t status = 0;
      if (packet.type == taskbar::PacketType::status && taskbar::DecodeCode(packet.payload, 5, &status))
        displayed |= status == static_cast<uint32_t>(taskbar::Status::displaying);
    }
    Sleep(10);
  }
  std::printf("%s isolated helper attaches to its own hidden fake taskbar\n", displayed ? "PASS" : "FAIL");
  frame.enabled = false;
  ok = ok && taskbar::EncodeFrame(frame, &payload) && taskbar::WritePacket(input_writer, taskbar::PacketType::frame, payload);
  deadline = GetTickCount64() + 1500;
  while (ok && GetTickCount64() < deadline && !disabled) {
    std::vector<taskbar::Packet> packets;
    ok = taskbar::ReadPipeAvailable(output, &buffer, &packets);
    for (const auto& packet : packets) {
      uint32_t status = 0;
      if (packet.type == taskbar::PacketType::status && taskbar::DecodeCode(packet.payload, 5, &status))
        disabled |= status == static_cast<uint32_t>(taskbar::Status::disabled);
    }
    Sleep(10);
  }
  std::printf("%s disabled frame withdraws child display\n", disabled ? "PASS" : "FAIL");
  CloseHandle(input_writer);
  bool exited = WaitForSingleObject(process.hProcess, 3000) == WAIT_OBJECT_0;
  std::printf("%s parent pipe disconnect tears down helper\n", exited ? "PASS" : "FAIL");
  if (!exited) TerminateProcess(process.hProcess, 7);  // Only the process created by this fixture.
  CloseHandle(process.hProcess); CloseHandle(output);
  return displayed && disabled && exited ? 0 : 1;
}
