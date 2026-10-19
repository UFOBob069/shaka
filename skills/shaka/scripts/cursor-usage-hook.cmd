@echo off
setlocal EnableExtensions
rem Cursor's hook process cannot run an extensionless Ruby script, and ruby.exe
rem may be missing from that process PATH. Find it on the saved user or machine PATH.
set "SCRIPT=%~dp0cursor-usage-hook"
set "FOUND=%TEMP%\shaka-ruby-path.txt"
powershell -NoProfile -Command "$out = Join-Path $env:TEMP 'shaka-ruby-path.txt'; $paths = @($env:Path); foreach ($key in @('HKCU:\Environment', 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment')) { $entry = (Get-ItemProperty -Path $key -Name Path -ErrorAction SilentlyContinue).Path; if ($entry) { $paths += [Environment]::ExpandEnvironmentVariables($entry) } }; $hit = ''; foreach ($dir in ($paths -join ';' -split ';')) { $dir = $dir.Trim(); if ($dir -and (Test-Path -LiteralPath (Join-Path $dir 'ruby.exe'))) { $hit = Join-Path $dir 'ruby.exe'; break } }; Set-Content -LiteralPath $out -Encoding ascii -Value $hit" <nul
set "RUBY="
set /p RUBY=<"%FOUND%"
del "%FOUND%" >nul 2>&1
if not defined RUBY exit /b 0
"%RUBY%" --disable-gems --disable-rubyopt "%SCRIPT%"
exit /b %ERRORLEVEL%
