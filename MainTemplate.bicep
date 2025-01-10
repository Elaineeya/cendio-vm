@description('The name of your Virtual Machine.')
param vmName string = 'basicLinuxVM'

@description('Username for the Virtual Machine.')
param adminUsername string

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'password'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

@description('Unique DNS Name for the Public IP used to access the Virtual Machine.')
param publicIpDns string = toLower('${vmName}-${uniqueString(resourceGroup().id)}')

@description('The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version.')
@allowed([
  'thinlinc-ubuntu'
  'Ubuntu-2204'
])
param ubuntuOSVersion string = 'thinlinc-ubuntu'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The size of the VM')
param vmSize string = 'Standard_D2s_v3'

@description('Name of the virtual network')
param virtualNetworkName string = 'vNet'

@description('Address prefix of the virtual network')
param addressPrefix array = [
  '10.1.0.0/16'
]

@description('Virtual network is new or existing.')
param virtualNetworkNewOrExisting string = 'new'

@description('Resource group of the virtual network.')
param virtualNetworkRGName string = resourceGroup().name

@description('Name of the subnet in the virtual network')
param subnetName string = 'basic-subnet'

@description('Subnet prefix of the virtual network')
param subnetAddressPrefix string = '10.1.0.0/24'

@description('Unique public IP address name')
param publicIpName string = 'basiclinuxvm-ip'

@description('Public IP new or existing or none?')
param publicIpNewOrExisting string = 'new'

@description('Resource group of the public IP address.')
param publicIpRGName string = resourceGroup().name

@description('Name of the Network Security Group')
param networkSecurityGroupName string = '${vmName}-nsg'

@description('Security Type of the Virtual Machine.')
@allowed([
  'Standard'
  'TrustedLaunch'
])
param securityType string = 'Standard'

@description('Tags by resource')
param outTagsByResource object = {}

@description('customData is passed to the VM to be saved as a file for cloud-init')
param customData string = 'mate'

var imageReference = {
  'thinlinc-ubuntu': {
    publisher: 'cendio'
    offer: 'thinlinc'
    sku: 'thinlinc-ubuntu-2204'
    version: 'latest'
  }
  'Ubuntu-2204': {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    version: 'latest'
  }
}

var networkInterfaceName = '${vmName}NetInt'
var osDiskType = 'Standard_LRS'
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}
var securityProfileJson = {
  uefiSettings: {
    secureBootEnabled: true
    vTpmEnabled: true
  }
  securityType: securityType
}
var extensionName = 'GuestAttestation'
var extensionPublisher = 'Microsoft.Azure.Security.LinuxAttestation'
var extensionVersion = '1.0'
var maaTenantName = 'GuestAttestation'
var maaEndpoint = substring('emptystring', 0, 0)

var tags = {
  offer: 'Sample Basic Linux 2204 VM'
}

var publicIpId = {
  new: resourceId('Microsoft.Network/publicIPAddresses', publicIpName)
  existing: resourceId(publicIpRGName, 'Microsoft.Network/publicIPAddresses', publicIpName)
  none: ''
}[publicIpNewOrExisting]

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2023-06-01' = if (publicIpNewOrExisting == 'new') {
  name: publicIpName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: publicIpDns
    }
    idleTimeoutInMinutes: 4
  }
  tags: (contains(outTagsByResource, 'Microsoft.Network/publicIPAddresses')
    ? union(tags, outTagsByResource['Microsoft.Network/publicIPAddresses'])
    : tags)
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-06-01' = if (virtualNetworkNewOrExisting == 'new') {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        first(addressPrefix)
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
  tags: (contains(outTagsByResource, 'Microsoft.Network/virtualNetworks')
    ? union(tags, outTagsByResource['Microsoft.Network/virtualNetworks'])
    : tags)
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-06-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: ((!empty(publicIpId)) ? publicIPAddress.id : null)
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
  tags: (contains(outTagsByResource, 'Microsoft.Network/networkInterfaces')
    ? union(tags, outTagsByResource['Microsoft.Network/networkInterfaces'])
    : tags)
}


resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: imageReference[ubuntuOSVersion]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      customData: base64(customData)
      linuxConfiguration: ((authenticationType == 'password') ? null : linuxConfiguration)
    }
    securityProfile: (securityType == 'TrustedLaunch') ? securityProfileJson : null
  }
  plan: {
    name: 'thinlinc-ubuntu-2204'
    product: 'thinlinc'
    publisher: 'cendio'
  }
  tags: (contains(outTagsByResource, 'Microsoft.Compute/virtualMachines')
    ? union(tags, outTagsByResource['Microsoft.Compute/virtualMachines'])
    : tags)
}

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (securityType == 'TrustedLaunch' && securityProfileJson.uefiSettings.secureBootEnabled && securityProfileJson.uefiSettings.vTpmEnabled) {
  parent: vm
  name: extensionName
  location: location
  properties: {
    publisher: extensionPublisher
    type: extensionName
    typeHandlerVersion: extensionVersion
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      AttestationConfig: {
        MaaSettings: {
          maaEndpoint: maaEndpoint
          maaTenantName: maaTenantName
        }
      }
    }
  }
}

output adminUsername string = adminUsername
output hostname string = publicIPAddress.properties.dnsSettings.fqdn
output sshCommand string = 'ssh ${adminUsername}@${publicIPAddress.properties.dnsSettings.fqdn}'
output unusedVirtualNetworkRGName string = virtualNetworkRGName
