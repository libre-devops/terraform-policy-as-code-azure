Feature: VM Sizes policy

  Scenario: Ensure only selected VM sizes are used for Windows VMs
    Given I have azurerm_windows_virtual_machine defined
    Then it must have size
    And its value must match the "(Standard_B2s|Standard_B2ms|Standard_B4ms|Standard_D2_v4)" regex

  Scenario: Ensure only selected VM sizes are used for Linux VMs
    Given I have azurerm_linux_virtual_machine defined
    Then it must have size
    And its value must match the "(Standard_B2s|Standard_B2ms|Standard_B4ms|Standard_D2_v4)" regex
