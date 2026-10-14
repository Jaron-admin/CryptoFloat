#ifndef RUNNER_TASKBAR_PROTOCOL_H_
#define RUNNER_TASKBAR_PROTOCOL_H_
#include "taskbar_host.h"
namespace taskbar {
constexpr size_t kMaxPacket = 65536;
enum class PacketType : uint32_t { frame = 1, status = 2, action = 3 };
enum class Status : uint32_t { disabled, displaying, waiting, noSpace, unsupported, error };
enum class Action : uint32_t { show = 1, settings, refresh, disable, exit };
enum class DiagnosticSource { bridge, helper };
// Local bounded logs contain only fixed reason labels and numeric diagnostics.
// Separate files prevent bridge/helper rotation from racing across processes.
void WriteDiagnostic(DiagnosticSource source, const std::string& message);
struct Packet { PacketType type = PacketType::frame; std::vector<uint8_t> payload; };
bool ValidateFrame(const TaskbarFrame& frame);
bool EncodeFrame(const TaskbarFrame& frame, std::vector<uint8_t>* payload);
bool DecodeFrame(const std::vector<uint8_t>& payload, TaskbarFrame* frame);
bool EncodePacket(PacketType type, const std::vector<uint8_t>& payload,
                  std::vector<uint8_t>* packet);
// Returns false for an invalid stream; consumes only complete bounded packets.
bool ConsumePackets(std::vector<uint8_t>* buffer, std::vector<Packet>* packets);
std::vector<uint8_t> EncodeCode(uint32_t code);
bool DecodeCode(const std::vector<uint8_t>& payload, uint32_t maximum, uint32_t* code);
const char* StatusName(Status status);
const char* ActionName(Action action);
bool ReadPipeAvailable(HANDLE pipe, std::vector<uint8_t>* buffer, std::vector<Packet>* packets);
bool WritePacket(HANDLE pipe, PacketType type, const std::vector<uint8_t>& payload);
}
#endif
