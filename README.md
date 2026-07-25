# mado
A PowerShell script to minimally better user experience for common users on Windows, using common techniques. Powered by WinGet and other package managers.

Code written by Gemini 3.1 Pro Extended and Gemini 3.1 Flash-Lite Extended. The conversation with Pro Extended can be found on [https://share.gemini.google/5XMvAHmiNs0n](https://share.gemini.google/5XMvAHmiNs0n); the one with Flash-Lite can be found on [https://share.gemini.google/5cVg9xPUdj1j](https://share.gemini.google/5cVg9xPUdj1j).

The script does the following:
- Install Windows Terminal, PowerShell 7, Yazi, Neovim, Brave Browser, and ONLYOFFICE Desktop Editors
- Ask users to consider using [Ecosia](https://www.ecosia.org/)

## Installation
On PowerShell 5.1+ with administrative privileges on Windows, execute (can be pasted at once)
```powershell
git clone https://github.com/elfry2/mado
cd mado
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
./Install.ps1
```
