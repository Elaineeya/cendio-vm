# Azure Marketplace Offer

This demonstrates how to build a solution template or managed application Azure Application offer in Azure Patner Center. 

Please refer to the [Microsoft Commercial Marketplace Offer](https://github.com/microsoft/commercial-marketplace-offer-solution/tree/main) for original scripts and documentation.

## Step 1: Install dependencies

Install the following tools on your development machine:
- Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
- Azure Partner Center CLI: https://github.com/microsoft/az-partner-center-cli/tree/main
- PowerShell: https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell?view=azps-13.1.0

## Step 2: Login to Azure

Sign in using the Azure CLI:
```
az login
```

## Step 3: Modify the template for your use case

In the [app-contents](marketplace/application/cendio-thinlinc-application/app-coontents), You can use this template as a base for your own solution template or managed application offer. Modify the `createUiDefinition.json` and Bicep templates (`mainTemplate.bicep`) to suit your needs.

### Customize the Portal User Interface

The `createUiDefinition.json` file specifies the portal user interface that is displayed to the customer when deploying your solution.

To test the portal interface for your solution, open the [Create UI Definition Sandbox](https://portal.azure.com/?feature.customPortal=false&#blade/Microsoft_Azure_CreateUIDef/SandboxBlade) and replace the empty definition with the contents of your `createUiDefinition.json` file. Select **Preview** and the form you created is displayed.

Please refer to the [Microsoft documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/create-uidefinition-elements) for more information on customizing the portal user interface.

### Customize the Bicep Templates

The Azure Application offer type requires an Azure Resource Manager (ARM) template to specify what resources are deployed. We recommend using Bicep to compose the templates. The packaging scripts ([PowerShell](scripts/package.ps1), [Shell](scripts/package.sh)) provided in the `scripts` folder of this repository will automatically convert your [Bicep](https://github.com/Azure/bicep) templates into a single ARM template (`mainTemplate.json`).

Please refer to the [Microsoft documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview?tabs=bicep) for more information on how to write Bicep templates.

## Step 4: Test the ARM template

In the [scripts] folder of this repository, you will find the PowerShell scripts you can use to deploy the offer.

1. If you don't already have an existing storage account, you can create one. Replace "MyResourceGroup" with your own resource group name.
```
az group create --name MyResourceGroup --location westus
az storage account create -n mystorageacct -g MyResourceGroup -l westus --sku Standard_LRS
```

2. Set parameters in a parameters file to override the default values set in the template's ARM template. You can find an example of a parameters file ([parameters.json.tmpl](marketplace/application/cendio-thinlinc-application/app-contents/parameters.json.tmpl)) in the `app-contents` folder.

3. Deploy the solution. Replace "MyResourceGroup" with your own resource group name. If you have a parameters file, you can use the `-parametersFile` parameter to specify the file.
```
./package.ps1 -assetsFolder ../marketplace/application/cendio-thinlinc-application/app-contents -releaseFolder release_01
./devDeploy.ps1 -resourceGroup MyResourceGroup -location westus -assetsFolder ./release_01/assets -parametersFile myparameters.json -storageAccountName mystorageacct
```

4. Cleanup the deployment. Replace "MyResourceGroup" with your own resource group name.
```
az group create --name MyResourceGroup
```

## Step 5: Prepare the offer

Update the [listing configuration file](marketplace/application/cendio-thinlinc-application/listing_config.json) (`listing.json`) with the information about your offer.


## Step 6: Prepare a Microsoft Entra application accessing to your Partner Center

1. Please refer to the [Microsoft documentation](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/submission-api-onboard) to create a Micorsoft Entra application.

2. Set config parameters in a config yml file to run `azpc` command. You can find an example of a parameters file ([config.yml.tmpl](scripts/config.yml.tmpl)) in the `scripts` folder.

#### config.yml
```yaml
tenant_id                   : "<Azure Tenant ID>"
azure_preview_subscription  : "<Azure Subscription>"
aad_id                      : "<Service Principal ID>"
aad_secret                  : "<Service Principal Secret>"
access_id                   : "<Service Principal ID>"
```

## Step 7: Create the Offer

A [script](scripts/addUpdate_azureApplicationOffer.ps1) is provided in the `scripts` folder of this repository to create the Azure Application (Solution Template or Managed Application) offer.

The template [offer listing config](marketplace/application/cendio-thinlinc-application/listing_config.json) contains 2 plan options:
- Solution Template (`cendio-thinlinc-application`)
- Managed Application (`cendio-thinlinc-application-app`)

The offer type that is created refers to the plan set in the [manifest file](marketplace/application/cendio-thinlinc-application/manifest.yml).

The script will package the solution, create an offer if it does not already exist, create a plan if it does not already exist, and upload the solution package and offer assets (logos). You can also use this script to update the offer or plan. Replace the offer name and plan name with your own values.

```
./addUpdate_azureApplicationOffer.ps1 -offerType "<offer type>" -assetsFolder ../marketplace/application/cendio-thinlinc-application -offerName thinlinc-app -planName cendio-thinlinc-application
```
Where "\<offer type>" has the option of st or ma, for solution template and managed application, respectively.

## Step 8: Publishing the Azure Application Offer
Once the draft offer created in the above step has been reviewed and confirmed, the offer can be submitted for publishing.

To start the publishing process:
```
azpc app publish --name "<offer name>"
```

## References
