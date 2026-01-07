### 🚀 C# Debugger Setup Guide

Follow these incremental steps to configure your .NET debugging environment in Cursor.

---

### 1. Initialize Setup

Run the following command in your terminal and follow the instruction:

```powershell
.\cursor-chsarp-debugger-setup.ps1

```

### 2. First-Run Debugger Configuration

Press **F5** to initiate the debugger. When prompted, follow this sequence:

1. **Select Configure Task**: This begins the linkage between your code and the compiler.
<img width="1119" height="221" alt="image" src="https://github.com/user-attachments/assets/ed1af5bf-21ea-49d6-bc5f-84fbcf34c569" />

2. **Create tasks.json**: Choose the option **Create tasks.json file from template**.
<img width="1148" height="267" alt="image" src="https://github.com/user-attachments/assets/ebb066a7-9fb0-49ac-9b42-9e17b7fc5f70" />

3. **Choose MS Build**: Select **.NET Core** (or the template matching your project type).
4. <img width="1164" height="271" alt="image" src="https://github.com/user-attachments/assets/403434c0-cf34-4fe9-93c9-0025983f30ec" />


> [!TIP]
> Once `tasks.json` is generated, simply hit **F5** again to start your debug session.

---

### 💡 Global Configuration

If you want this configuration available for **all** your .NET projects:

1. Go to **Preferences > User Settings**.
2. Add the launch configuration as described in this [VS Code issue discussion](https://github.com/microsoft/vscode/issues/18401#issuecomment-272400316).
