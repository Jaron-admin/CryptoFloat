# Include from windows/runner/CMakeLists.txt after the runner target exists.
# Both processes use the same bounded protocol implementation.
target_sources(${BINARY_NAME} PRIVATE
  "${CMAKE_CURRENT_LIST_DIR}/taskbar_host.cpp"
  "${CMAKE_CURRENT_LIST_DIR}/taskbar_protocol.cpp"
)
add_executable(duomonitor_taskbar WIN32
  "${CMAKE_CURRENT_LIST_DIR}/taskbar_main.cpp"
  "${CMAKE_CURRENT_LIST_DIR}/taskbar_protocol.cpp"
  "${CMAKE_CURRENT_LIST_DIR}/taskbar_layout.cpp"
  "${CMAKE_CURRENT_LIST_DIR}/runner.exe.manifest"
)
apply_standard_settings(duomonitor_taskbar)
target_compile_definitions(duomonitor_taskbar PRIVATE UNICODE _UNICODE NOMINMAX)
target_compile_options(duomonitor_taskbar PRIVATE /utf-8)
target_link_libraries(duomonitor_taskbar PRIVATE
  user32 gdi32 shell32 comctl32 ole32 oleaut32 uiautomationcore advapi32
)
add_dependencies(${BINARY_NAME} duomonitor_taskbar)
# Flutter stores a generator expression in its install prefix. Resolve the
# runner directory here so the install script never treats that literal as a path.
install(TARGETS duomonitor_taskbar RUNTIME DESTINATION "$<TARGET_FILE_DIR:${BINARY_NAME}>" COMPONENT Runtime)
