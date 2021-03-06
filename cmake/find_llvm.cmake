# Broken in macos. TODO: update clang, re-test, enable
if (NOT APPLE)
    option (ENABLE_EMBEDDED_COMPILER "Set to TRUE to enable support for 'compile' option for query execution" 1)
    option (USE_INTERNAL_LLVM_LIBRARY "Use bundled or system LLVM library. Default: system library for quicker developer builds." ${APPLE})
endif ()

if (ENABLE_EMBEDDED_COMPILER)
    if (USE_INTERNAL_LLVM_LIBRARY AND NOT EXISTS "${ClickHouse_SOURCE_DIR}/contrib/llvm/llvm/CMakeLists.txt")
        message (WARNING "submodule contrib/llvm is missing. to fix try run: \n git submodule update --init --recursive")
        set (USE_INTERNAL_LLVM_LIBRARY 0)
    endif ()

    if (NOT USE_INTERNAL_LLVM_LIBRARY)
        set (LLVM_PATHS "/usr/local/lib/llvm")

        if (LLVM_VERSION)
            find_package(LLVM ${LLVM_VERSION} CONFIG PATHS ${LLVM_PATHS})
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
            find_package(LLVM ${CMAKE_CXX_COMPILER_VERSION} CONFIG PATHS ${LLVM_PATHS})
        else ()
            find_package (LLVM 7 CONFIG PATHS ${LLVM_PATHS})
            if (NOT LLVM_FOUND)
                find_package (LLVM 6 CONFIG PATHS ${LLVM_PATHS})
            endif ()
            if (NOT LLVM_FOUND)
                find_package (LLVM 8 CONFIG PATHS ${LLVM_PATHS})
            endif ()
            if (NOT LLVM_FOUND)
                find_package (LLVM 5 CONFIG PATHS ${LLVM_PATHS})
            endif ()
        endif ()

        if (LLVM_FOUND)
            find_library (LLD_LIBRARY_TEST lldCore PATHS ${LLVM_LIBRARY_DIRS})
            find_path (LLD_INCLUDE_DIR_TEST NAMES lld/Core/AbsoluteAtom.h PATHS ${LLVM_INCLUDE_DIRS})
            if (NOT LLD_LIBRARY_TEST OR NOT LLD_INCLUDE_DIR_TEST)
                set (LLVM_FOUND 0)
                message(WARNING "liblld (${LLD_LIBRARY_TEST}, ${LLD_INCLUDE_DIR_TEST}) not found in ${LLVM_INCLUDE_DIRS} ${LLVM_LIBRARY_DIRS}. Disabling internal compiler.")
            endif ()
        endif ()

        if (LLVM_FOUND)
            # Remove dynamically-linked zlib and libedit from LLVM's dependencies:
            set_target_properties(LLVMSupport PROPERTIES INTERFACE_LINK_LIBRARIES "-lpthread;LLVMDemangle;${ZLIB_LIBRARIES}")
            set_target_properties(LLVMLineEditor PROPERTIES INTERFACE_LINK_LIBRARIES "LLVMSupport")

            option(LLVM_HAS_RTTI "Enable if LLVM was build with RTTI enabled" ON)
            set (USE_EMBEDDED_COMPILER 1)
        else()
            set (USE_EMBEDDED_COMPILER 0)
        endif()

        if (LLVM_FOUND AND OS_LINUX AND USE_LIBCXX)
            message(WARNING "Option USE_INTERNAL_LLVM_LIBRARY is not set but the LLVM library from OS packages in Linux is incompatible with libc++ ABI. LLVM Will be disabled.")
            set (LLVM_FOUND 0)
            set (USE_EMBEDDED_COMPILER 0)
        endif ()
    else()
        set (LLVM_FOUND 1)
        set (USE_EMBEDDED_COMPILER 1)
        set (LLVM_VERSION "7.0.0bundled")
        set (LLVM_INCLUDE_DIRS
            ${ClickHouse_SOURCE_DIR}/contrib/llvm/llvm/include
            ${ClickHouse_BINARY_DIR}/contrib/llvm/llvm/include
            ${ClickHouse_SOURCE_DIR}/contrib/llvm/clang/include
            ${ClickHouse_BINARY_DIR}/contrib/llvm/clang/include
            ${ClickHouse_BINARY_DIR}/contrib/llvm/llvm/tools/clang/include
            ${ClickHouse_SOURCE_DIR}/contrib/llvm/lld/include
            ${ClickHouse_BINARY_DIR}/contrib/llvm/lld/include
            ${ClickHouse_BINARY_DIR}/contrib/llvm/llvm/tools/lld/include)
        set (LLVM_LIBRARY_DIRS ${ClickHouse_BINARY_DIR}/contrib/llvm/llvm)
    endif()

    if (LLVM_FOUND)
        message(STATUS "LLVM version: ${LLVM_PACKAGE_VERSION}")
        message(STATUS "LLVM include Directory: ${LLVM_INCLUDE_DIRS}")
        message(STATUS "LLVM library Directory: ${LLVM_LIBRARY_DIRS}")
        message(STATUS "LLVM C++ compiler flags: ${LLVM_CXXFLAGS}")
    endif()
endif()


function(llvm_libs_all REQUIRED_LLVM_LIBRARIES)
    llvm_map_components_to_libnames (result all)
    if (USE_STATIC_LIBRARIES OR NOT "LLVM" IN_LIST result)
        list (REMOVE_ITEM result "LTO" "LLVM")
    else()
        set (result "LLVM")
    endif ()
    if (TERMCAP_LIBRARY)
        list (APPEND result ${TERMCAP_LIBRARY})
    endif ()
    list (APPEND result ${CMAKE_DL_LIBS} ${ZLIB_LIBRARIES})
    set (${REQUIRED_LLVM_LIBRARIES} ${result} PARENT_SCOPE)
endfunction()
