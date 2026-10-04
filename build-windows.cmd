@echo off
rem Build Windows logic tests: build\LogicTestsRunner.exe (no SwiftPM / XCTest)
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
set SW=D:\scoop\apps\swift\6.4.0\Toolchains\6.4.0+NoAsserts\usr\bin
set SDKROOT=D:\scoop\apps\swift\6.4.0\Platforms\Windows.platform\Developer\SDKs\Windows.sdk
set PATH=%SW%;%PATH%
cd /d E:\IT\Project\SwipeClean
if not exist build mkdir build

set SOURCES=SwipeClean\Models\PhotoItem.swift SwipeClean\Models\ReviewSession.swift SwipeClean\Models\DeletionQueue.swift SwipeClean\Models\ReviewAction.swift SwipeClean\Models\ReviewState.swift SwipeClean\Services\GestureCoordinator.swift SwipeClean\Persistence\LocalSessionStore.swift SwipeClean\Persistence\ReviewSessionStore.swift SwipeClean\Repositories\PhotoRepository.swift SwipeClean\Repositories\MockPhotoRepository.swift WindowsTests\main.swift

echo [1/2] compiling all sources (single module, WMO)...
swiftc -sdk "%SDKROOT%" -libc MD -nonlib-dependency-scanner -wmo -O -c %SOURCES% -o build\all.obj
if errorlevel 1 exit /b 1

echo [2/2] linking LogicTestsRunner (static)...
set STATICLIBDIR=D:\scoop\apps\swift\6.4.0\Platforms\Windows.platform\Developer\SDKs\Windows.sdk\usr\lib\swift_static\windows\x86_64
swiftc -sdk "%SDKROOT%" -libc MD build\all.obj -o build\LogicTestsRunner.exe
if errorlevel 1 exit /b 1

echo OK: build\LogicTestsRunner.exe
exit /b 0
