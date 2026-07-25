# mado
A PowerShell script to minimally better user experience on Windows. Powered by WinGet and other package managers.

Code written by Gemini 3.1 Pro Extended and Gemini 3.1 Flash-Lite Extended. The conversation with Pro Extended can be found on [https://share.gemini.google/5XMvAHmiNs0n](https://share.gemini.google/5XMvAHmiNs0n); the one with Flash-Lite can be found on [https://share.gemini.google/OGvX6v8yQEM3](https://share.gemini.google/OGvX6v8yQEM3).

The script does the following:
- Install Windows Terminal, PowerShell 7, LunarVim, Brave Browser, and ONLYOFFICE Desktop Editors
- Asks users to consider using [Ecosia](https://www.ecosia.org/)

## Installation
On PowerShell 5.1+ with administrative privileges on Windows, execute (can be pasted at once)
```powershell
git clone https://github.com/elfry2/mado
cd mado
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
./Install.ps1
```
