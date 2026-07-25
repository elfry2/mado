# mado
A PowerShell script to minimally better user experience on Windows. Powered by WinGet and other package managers.

Code written by Gemini 3.1 Pro Extended. The conversation can be found on [https://share.gemini.google/EGse3BYQKJCb](https://share.gemini.google/EGse3BYQKJCb).

The script does the following:
- Install Windows Terminal, PowerShell 7, Neovim, Neovide, Brave Browser, and ONLYOFFICE Desktop Editors
- Asks users to consider using [Ecosia](https://www.ecosia.org/)

## Installation
On PowerShell 5.1+ with administrative privileges on Windows, execute (can be pasted at once)
```powershell
git clone https://github.com/elfry2/mado
cd mado
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
./Install.ps1
```
