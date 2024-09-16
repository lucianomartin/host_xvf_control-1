# Building host device_control drivers here
# I2C and SPI drivers are only built for PI
if(${CMAKE_SYSTEM_PROCESSOR} STREQUAL armv7l)

# Build device_control_host for I2C
add_library(framework_rtos_sw_services_device_control_host_i2c INTERFACE)
target_sources(framework_rtos_sw_services_device_control_host_i2c
    INTERFACE
        ${DEVICE_CONTROL_PATH}/host/util.c
        ${DEVICE_CONTROL_PATH}/host/device_access_i2c_rpi.c
)
target_include_directories(framework_rtos_sw_services_device_control_host_i2c
    INTERFACE
        ${DEVICE_CONTROL_PATH}/api
        ${DEVICE_CONTROL_PATH}/host
)
target_compile_definitions(framework_rtos_sw_services_device_control_host_i2c INTERFACE USE_I2C=1 RPI=1)
add_library(rtos::sw_services::device_control_host_i2c ALIAS framework_rtos_sw_services_device_control_host_i2c)

# Link SPI driver
set(SPI_DRIVER ${CMAKE_CURRENT_LIST_DIR}/device/spi_driver)
add_library(bcm2835 STATIC IMPORTED)
set_property(TARGET bcm2835 PROPERTY IMPORTED_LOCATION ${SPI_DRIVER}/libbcm2835.a)
target_include_directories(bcm2835 INTERFACE ${SPI_DRIVER})

# Build device_control_host for SPI
add_library(framework_rtos_sw_services_device_control_host_spi INTERFACE)
target_sources(framework_rtos_sw_services_device_control_host_spi
    INTERFACE
        ${DEVICE_CONTROL_PATH}/host/util.c
        ${DEVICE_CONTROL_PATH}/host/device_access_spi_rpi.c
)
target_include_directories(framework_rtos_sw_services_device_control_host_spi
    INTERFACE
        ${DEVICE_CONTROL_PATH}/api
        ${DEVICE_CONTROL_PATH}/host
)

target_link_libraries(framework_rtos_sw_services_device_control_host_spi INTERFACE bcm2835)

target_compile_definitions(framework_rtos_sw_services_device_control_host_spi INTERFACE USE_SPI=1 RPI=1)
add_library(rtos::sw_services::device_control_host_spi ALIAS framework_rtos_sw_services_device_control_host_spi)

# Build a wrapper driver for i2c

add_library(device_i2c SHARED)
target_sources(device_i2c
    PRIVATE
        ${CMAKE_CURRENT_LIST_DIR}/device/device_i2c.cpp

)
target_include_directories(device_i2c
    PUBLIC
        ${CMAKE_CURRENT_LIST_DIR}/device
        ${DEVICE_CONTROL_PATH}/host
)
target_link_libraries(device_i2c
    PUBLIC
        rtos::sw_services::device_control_host_i2c
)
target_link_options(device_i2c PRIVATE -fPIC)

# Build a wrapper driver for spi

add_library(device_spi SHARED)
target_sources(device_spi
    PRIVATE
        ${CMAKE_CURRENT_LIST_DIR}/device/device_spi.cpp
)
target_include_directories(device_spi
    PUBLIC
        ${CMAKE_CURRENT_LIST_DIR}/device
        ${DEVICE_CONTROL_PATH}/host
)
target_link_libraries(device_spi
    PUBLIC
        rtos::sw_services::device_control_host_spi
)
target_link_libraries(device_spi PRIVATE -fPIC)

endif() # armv7l

# Build device_control_host for USB

add_library(framework_rtos_sw_services_device_control_host_usb INTERFACE)

# Discern OS for libusb library location
if ((${CMAKE_SYSTEM_NAME} MATCHES "Darwin") AND (${CMAKE_SYSTEM_PROCESSOR} MATCHES "x86_64"))
    target_link_directories(framework_rtos_sw_services_device_control_host_usb INTERFACE "${DEVICE_CONTROL_PATH}/host/libusb/OSX64")
    set(libusb-1.0_INCLUDE_DIRS "${DEVICE_CONTROL_PATH}/host/libusb/OSX64")
    set(LINK_LIBS usb-1.0.0)
elseif ((${CMAKE_SYSTEM_NAME} MATCHES "Darwin") AND (${CMAKE_SYSTEM_PROCESSOR} MATCHES "arm64"))
    target_link_directories(framework_rtos_sw_services_device_control_host_usb INTERFACE "${DEVICE_CONTROL_PATH}/host/libusb/OSXARM")
    set(libusb-1.0_INCLUDE_DIRS "${DEVICE_CONTROL_PATH}/host/libusb/OSXARM")
    set(LINK_LIBS usb-1.0.0)
elseif (${CMAKE_SYSTEM_NAME} MATCHES "Linux")
    find_package(PkgConfig)
    pkg_check_modules(libusb-1.0 REQUIRED libusb-1.0)
    set(LINK_LIBS usb-1.0)
elseif (${CMAKE_SYSTEM_NAME} MATCHES "Windows")
    add_compile_definitions(nologo WAll WX- O2 EHa)
    target_link_directories(framework_rtos_sw_services_device_control_host_usb INTERFACE "${DEVICE_CONTROL_PATH}/host/libusb/Win32")
    set(libusb-1.0_INCLUDE_DIRS "${DEVICE_CONTROL_PATH}/host/libusb/Win32")
    set(LINK_LIBS libusb-1.0)
endif()

target_sources(framework_rtos_sw_services_device_control_host_usb
    INTERFACE
        ${DEVICE_CONTROL_PATH}/host/util.c
        ${DEVICE_CONTROL_PATH}/host/device_access_usb.c
)
target_include_directories(framework_rtos_sw_services_device_control_host_usb
    INTERFACE
        ${DEVICE_CONTROL_PATH}/api
        ${DEVICE_CONTROL_PATH}/host
        ${libusb-1.0_INCLUDE_DIRS}
)
target_compile_definitions(framework_rtos_sw_services_device_control_host_usb INTERFACE USE_USB=1)

target_link_libraries(framework_rtos_sw_services_device_control_host_usb
    INTERFACE
        ${LINK_LIBS}
)
add_library(rtos::sw_services::device_control_host_usb ALIAS framework_rtos_sw_services_device_control_host_usb)

# Build a wrapper driver for USB

add_library(device_usb SHARED)
target_sources(device_usb
    PRIVATE
        ${CMAKE_CURRENT_LIST_DIR}/device/device_usb.cpp
)
target_include_directories(device_usb
    PUBLIC
        ${CMAKE_CURRENT_LIST_DIR}/device
        ${DEVICE_CONTROL_PATH}/host
)
target_link_libraries(device_usb
    PUBLIC
        rtos::sw_services::device_control_host_usb
)

target_link_libraries(device_usb PRIVATE -fPIC)

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    add_custom_command(
        TARGET device_usb
        POST_BUILD
        COMMAND ${CMAKE_INSTALL_NAME_TOOL} -change "/usr/local/lib/libusb-1.0.0.dylib" "@executable_path/libusb-1.0.0.dylib" ${CMAKE_BINARY_DIR}/"libdevice_usb.dylib"
    )
    add_custom_command(
        TARGET device_usb
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy ${DEVICE_CONTROL_PATH}/host/libusb/OSX64/libusb-1.0.0.dylib ${CMAKE_BINARY_DIR}
    )
endif()

# Build device_control_host for HID

add_library(framework_rtos_sw_services_device_control_host_hid INTERFACE)

# Discern OS for hidapi library location
if ((${CMAKE_SYSTEM_NAME} MATCHES "Darwin") AND (${CMAKE_SYSTEM_PROCESSOR} MATCHES "x86_64"))
    target_link_directories(framework_rtos_sw_services_device_control_host_usb INTERFACE "${DEVICE_CONTROL_PATH}/host/libusb/OSX64")
    set(libusb-1.0_INCLUDE_DIRS "${DEVICE_CONTROL_PATH}/host/libusb/OSX64")
    set(LINK_LIBS usb-1.0.0)
elseif ((${CMAKE_SYSTEM_NAME} MATCHES "Darwin") AND (${CMAKE_SYSTEM_PROCESSOR} MATCHES "arm64"))
    target_link_directories(framework_rtos_sw_services_device_control_host_usb INTERFACE "${DEVICE_CONTROL_PATH}/host/libusb/OSXARM")
    set(libusb-1.0_INCLUDE_DIRS "${DEVICE_CONTROL_PATH}/host/libusb/OSXARM")
    set(LINK_LIBS usb-1.0.0)
elseif (${CMAKE_SYSTEM_NAME} MATCHES "Linux")
    find_package(PkgConfig)
    pkg_check_modules(libusb-1.0 REQUIRED libusb-1.0)
    set(LINK_LIBS usb-1.0)
elseif (${CMAKE_SYSTEM_NAME} MATCHES "Windows")
    add_compile_definitions(nologo WAll WX- O2 EHa)
    target_link_directories(framework_rtos_sw_services_device_control_host_hid INTERFACE "${DEVICE_CONTROL_PATH}/host/hidapi/Win32")
    set(hidapi_INCLUDE_DIRS "${DEVICE_CONTROL_PATH}/host/hidapi/include")
    set(LINK_LIBS hidapi)
endif()

target_sources(framework_rtos_sw_services_device_control_host_hid
    INTERFACE
        ${DEVICE_CONTROL_PATH}/host/util.c
        ${DEVICE_CONTROL_PATH}/host/device_access_hid.c
)
target_include_directories(framework_rtos_sw_services_device_control_host_hid
    INTERFACE
        ${DEVICE_CONTROL_PATH}/api
        ${DEVICE_CONTROL_PATH}/host
        ${hidapi_INCLUDE_DIRS}
)
target_compile_definitions(framework_rtos_sw_services_device_control_host_hid INTERFACE USE_HID=1)

target_link_libraries(framework_rtos_sw_services_device_control_host_hid
    INTERFACE
        ${LINK_LIBS}
)
add_library(rtos::sw_services::device_control_host_hid ALIAS framework_rtos_sw_services_device_control_host_hid)

# Build a wrapper driver for HID

add_library(device_hid SHARED)
target_sources(device_hid
    PRIVATE
        ${CMAKE_CURRENT_LIST_DIR}/device/device_hid.cpp
)
target_include_directories(device_hid
    PUBLIC
        ${CMAKE_CURRENT_LIST_DIR}/device
        ${DEVICE_CONTROL_PATH}/host
)
target_link_libraries(device_hid
    PUBLIC
        rtos::sw_services::device_control_host_hid
)

target_link_libraries(device_hid PRIVATE -fPIC)

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    add_custom_command(
        TARGET device_usb
        POST_BUILD
        COMMAND ${CMAKE_INSTALL_NAME_TOOL} -change "/usr/local/lib/libusb-1.0.0.dylib" "@executable_path/libusb-1.0.0.dylib" ${CMAKE_BINARY_DIR}/"libdevice_usb.dylib"
    )
    add_custom_command(
        TARGET device_usb
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy ${DEVICE_CONTROL_PATH}/host/libusb/OSX64/libusb-1.0.0.dylib ${CMAKE_BINARY_DIR}
    )
elseif(${CMAKE_SYSTEM_NAME} MATCHES "Windows")
    # Define the path to the hidapi.dll
    set(HIDAPI_DLL_PATH "${DEVICE_CONTROL_PATH}/host/hidapi/Win64/${HIDAPI_VERSION}/hidapi.dll")

    # Add a custom command to copy the hidapi.dll to the output directory of the target
    add_custom_command(TARGET device_hid POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${HIDAPI_DLL_PATH}"
        $<TARGET_FILE_DIR:device_hid>
    )
endif()
