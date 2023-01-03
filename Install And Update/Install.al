codeunit 82532 "PIMX SC Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    begin
        Session.LogMessage('PIMXLC06', 'Pimics - Sana Commerce has been installed', Verbosity::Normal, DataClassification::OrganizationIdentifiableInformation, TelemetryScope::All, 'CompanyName', CompanyName());
    end;
}