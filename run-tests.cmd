@echo off
rem Run Windows logic tests with runtime DLLs
set PATH=E:\IT\Project\SwipeClean\build\rt;%PATH%
E:\IT\Project\SwipeClean\build\LogicTestsRunner.exe
exit /b %ERRORLEVEL%
