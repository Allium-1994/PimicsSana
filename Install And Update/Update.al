codeunit 82531 "PIMX SC Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany();
    var
        Module: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(Module);
        Session.LogMessage('PIMXLC04', 'Pimics - Sana Commerce has been upgraded', Verbosity::Normal, DataClassification::OrganizationIdentifiableInformation, TelemetryScope::All, 'DataVersion', format(Module.DataVersion), 'CompanyName', CompanyName());
    end;
}