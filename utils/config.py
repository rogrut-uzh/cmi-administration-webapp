"""Central configuration for CMI Administration Webapp"""

import os
from pathlib import Path
from typing import Final


class AppConfig:
    """Application configuration constants"""
    
    # Base paths
    BASE_DIR: Final[Path] = Path(os.getcwd())
    PWSH_DIR: Final[Path] = BASE_DIR / 'pwsh'
    
    # PowerShell scripts
    PWSH_SCRIPTS: Final[dict[str, Path]] = {
        'service_control': PWSH_DIR / 'cmi-control-single-service.ps1',
        'download_logs': PWSH_DIR / 'cmi-download-log-files.ps1',
        'download_config': PWSH_DIR / 'cmi-download-config-files.ps1',
        'metatool': PWSH_DIR / 'cmi-metatool.ps1',
        'database_backup': PWSH_DIR / 'cmi-database-backup.ps1',
    }
    
    # Timeouts (in seconds)
    TIMEOUT_DEFAULT: Final[int] = 35
    TIMEOUT_LONG: Final[int] = 120
    TIMEOUT_SHORT: Final[int] = 15
    
    # API Configuration
    CMI_CONFIG_API_URL: Final[str] = 'http://localhost:5001/api/data'
    
    @classmethod
    def get_script_path(cls, script_name: str) -> Path:
        """Get path to PowerShell script by name
        
        Args:
            script_name: Name of the script (e.g., 'service_control')
            
        Returns:
            Path to the PowerShell script
            
        Raises:
            KeyError: If script name is not found
        """
        if script_name not in cls.PWSH_SCRIPTS:
            raise KeyError(f"Unknown PowerShell script: {script_name}")
        return cls.PWSH_SCRIPTS[script_name]
