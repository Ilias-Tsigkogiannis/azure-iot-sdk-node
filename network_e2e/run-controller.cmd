@setlocal EnableDelayedExpansion
@echo off

set SDK_ROOT=..
set TESTS_ROOT=%SDK_ROOT%\\network_e2e\\tests
set TARGET_SDK_ROOT=C:\\node-sdk\\
set DEVICE_CONNECTION_STRING=default

set AMQP_DEVICE_ID=node-network-e2e-amqp-%RANDOM%
set AMQP_WS_DEVICE_ID=node-network-e2e-amqp-ws-%RANDOM%
set MQTT_DEVICE_ID=node-network-e2e-mqtt-%RANDOM%
set MQTT_WS_DEVICE_ID=node-network-e2e-mqtt-ws-%RANDOM%
REM set HTTP_DEVICE_ID=node-network-e2e-http-%RANDOM%

REM Setup environment
call docker network create -d nat --gateway 172.22.17.1 --subnet=172.22.17.0/24 TestNat
if errorlevel 1 goto :eof

pushd %TESTS_ROOT%
call npm install
if errorlevel 1 goto :eof
popd

call :create-device %AMQP_DEVICE_ID%
call :create-env-file amqp_env.txt

call :create-device %AMQP_WS_DEVICE_ID%
call :create-env-file amqp_ws_env.txt

call :create-device %MQTT_DEVICE_ID%
call :create-env-file mqtt_env.txt

call :create-device %MQTT_WS_DEVICE_ID%
call :create-env-file mqtt_ws_env.txt

REM call :create-device %HTTP_DEVICE_ID%
REM call :create-env-file http_env.txt

call docker build ^
 -t networke2e/node-base ^
 - < Dockerfile.win.base
if errorlevel 1 goto :eof

call docker build ^
 --build-arg SDK_ROOT=%TARGET_SDK_ROOT% ^
 -t networke2e/node-test ^
 -f Dockerfile.win.test %SDK_ROOT%\\
if errorlevel 1 goto :eof

REM Run tests
call docker-compose up

SET /A EXIT_CODE=0
FOR /F "tokens=* USEBACKQ" %%L IN (`docker-compose ps -q`) DO (
  FOR /F "tokens=* USEBACKQ" %%C IN (`docker inspect %%L -f {{.State.ExitCode}}`) DO (
    SET /A EXIT_CODE=!EXIT_CODE! + %%C
  )
)

REM REM Cleanup
goto :cleanup

:create-device
pushd %TESTS_ROOT%
echo Creating device %1
for /F "tokens=* USEBACKQ" %%F IN (`node create-device.js %1`) DO (
  if errorlevel 1 goto :eof
  set DEVICE_CONNECTION_STRING=%%F
  echo Device %1 created with connection string !DEVICE_CONNECTION_STRING!
)
popd
goto :eof

:delete-device
pushd %TESTS_ROOT%
echo Deleting device %1
for /F "tokens=* USEBACKQ" %%F IN (`node delete-device.js %1`) DO (
  if errorlevel 1 goto :eof
  echo Device %1 deleted
)
popd
goto :eof

:create-env-file
ECHO Writing to %1
echo DEVICE_CONNECTION_STRING=!DEVICE_CONNECTION_STRING! >> %1
echo IOTHUB_CONNECTION_STRING=%IOTHUB_CONNECTION_STRING% >> %1
echo DOCKER_HOST=tcp://172.22.17.1:2375 >> %1
goto :eof

:cleanup
call docker network rm TestNat

call :delete-device %AMQP_DEVICE_ID%
call :delete-device %AMQP_WS_DEVICE_ID%
call :delete-device %MQTT_DEVICE_ID%
call :delete-device %MQTT_WS_DEVICE_ID%
REM call :delete-device %HTTP_WS_DEVICE_ID%

FOR %%F in (amqp_env.txt amqp_ws_env.txt mqtt_env.txt mqtt_ws_env.txt) DO (
  REM Missing HTTP for now
  call DEL %%F
)

:exit
EXIT /B !EXIT_CODE!

@endlocal
