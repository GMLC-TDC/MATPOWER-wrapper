@echo off

REM local variables
SETLOCAL

REM Base Code directory
REM set CODEBase=C:\gld_730_helics\gridlab-d
REM CODEBaseFor=C:/gld_730_helics/gridlab-d
set HELICS=C:\Users\mukh915\Anaconda3\Lib\site-packages\helics\install
set PYTHON=C:\Users\mukh915\Anaconda3\
rem set PYTHON=C:\Users\sing492\Miniconda3


REM Add path to current GLD install (run from there)
REM set PATH=C:\windows\system32;C:\windows;C:\windows\System32\Wbem;C:\windows\System32\OpenSSH;%CODEBase%\install64\bin;%PYTHON%;%PYTHON%\Scripts;%HELICS%;%HELICS%\bin;%HELICS%\lib

set PATH=%CODEBase%\install64\bin;%PYTHON%;%PYTHON%\Scripts;%HELICS%;%HELICS%\bin;%HELICS%\lib


REM Set GLPATH - it's the same for both
REM set GLPATH=%CODEBase%\install64\lib\gridlabd;%CODEBase%\install64\share\gridlabd;%CODEBase%\install64\include\gridlabd

REM Set for compiler
REM set CXXFLAGS=-I%CODEBaseFor%/install64/share/gridlabd

REM change to that folder
rem cd %CODEBase%

REM See if the "compiler leftovers" are in here
if exist "helics_broker.exe" (
	del /q /f helics_broker.exe
)


start /b cmd /c helics_broker --version > broker.log 2^>^&1

start C:\Program^ Files\MATLAB\R2020b\bin\matlab.exe -nosplash -nodesktop -r ISO_Simulator
