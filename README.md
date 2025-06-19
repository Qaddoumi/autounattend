# Windows Autounattend Tool

An automated Windows installation configuration tool that creates custom unattended installation ISOs for Windows.

## Features

- Creates automated Windows installation configurations
- Supports multiple virtualization platforms:
  - VirtualBox Guest Additions
  - VMware Tools 
  - VirtIO Guest Tools
- Customizable system settings:
  - Language and locale settings
  - Time zone configuration
  - Power settings
  - User account creation
  - Auto-login configuration
- Bypass installation requirements:
  - TPM check
  - Secure Boot check
  - RAM check
- Post-installation optimizations:
  - Disable fast startup
  - Enable long paths
  - Show file extensions
  - Disable app suggestions
  - Clean start menu configuration

## Requirements

### Windows
- PowerShell 5.0 or later

### Linux/macOS
- `genisoimage` or `mkisofs` package installed

## Installation and Usage

1. Clone this repository:
```bash
git clone https://github.com/yourusername/autounattend.git
cd autounattend
```

2. PowerShell (Windows)

```powershell
# Generate ISO using PowerShell script
.\make_unattend_ISO.ps1
```

3. Bash (Linux/macOS)

```bash
# Generate ISO using Bash script
chmod +x make_unattend_ISO.sh
./make_unattend_ISO.sh
```

### Command Line Options (Bash script)

```
Options:
  -s, --source FILE    Source file to include in ISO (default: ./autounattend.xml)
  -o, --output FILE    Output ISO path
  -t, --title TITLE    Volume title (default: autounattend)
  -m, --media TYPE     Media type (default: CDR)
  -b, --boot FILE      Boot image file
  -f, --force         Overwrite existing output file
  -h, --help          Show this help message
```

## Customization

Edit the `autounattend.xml` file to customize the installation settings:

- Language and locale settings
- Time zone configuration
- User accounts setup
- System preferences
- Post-installation scripts
- Virtual machine tools installation

## Project Structure

```
autounattend/
├── README.md
├── autounattend.xml
├── make_unattend_ISO.ps1
└── make_unattend_ISO.sh
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

For support, please open an issue in the GitHub repository.

