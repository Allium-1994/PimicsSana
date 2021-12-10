codeunit 82530 "PIMX SC Subscriber"
{
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"SC - Product Functions", 'OnBeforeGetProducts', '', true, true)]
    local procedure SCProduct_OnBeforeGetProducts(var XMLNodeBuff: Record "SC - XML Buffer (dotNET)"; var Item: Record Item; var Params: Record "SC - Parameters Collection");
    var
        publLine: Record "PIMX Publication Line";
        publHeader: Record "PIMX Publication Header";
        FilterText: Text;
        lock: List of [Text];
        i: Integer;
        q: Query "PIMX SC Items or Groups";
    begin
        if not publHeader.GetByExternalCode(Params.WebsiteId) then
            exit;

        if not GetDateFilter(Params, FilterText) then
            exit;

        for i := 1 to 2 do begin
            q.SetRange(item_Zeilenart, publLine.Zeilenart::Artikel); //
            q.SetRange(item_Code, publHeader.Code);
            case i of
                1:
                    q.SetFilter(data_Data_Updated_On, FilterText);
                2:
                    q.SetFilter(item_Data_Updated_On, FilterText);
            end;
            if q.Open() then
                while q.Read() do
                    if not lock.Contains(q.item_Nummer) then begin
                        Item.SetRange("No.", q.item_Nummer);
                        if Item.FINDFIRST() then
                            Item.Mark(true);
                        lock.Add(q.item_Nummer);
                    end;
            item.SetRange("No.");
        end;
        Session.LogMessage('PIMXSC101', 'Publication ' + Params.WebsiteId, Verbosity::Normal, DataClassification::EndUserPseudonymousIdentifiers, TelemetryScope::All, 'itemQty', format(lock.Count()), 'filter', FilterText);
        Params.IndexRecords := 0;
    end;

    local procedure GetDateFilter(var Params: Record "SC - Parameters Collection"; var FilterText: Text): boolean
    var
        ValueHelper: Codeunit "SC - Filter Helper";
        TempFilterList: Record "SC - Key Value" temporary;
        fr: FieldRef;
        rr: RecordRef;
    begin
        Params.GetFilterList(TempFilterList);
        if not TempFilterList.Get('SC Last Date/Time Modified') then begin
            Session.LogMessage('PIMXSC102', 'Missing parameter "SC Last Date/Time Modified"', Verbosity::Warning, DataClassification::EndUserPseudonymousIdentifiers, TelemetryScope::All, 'filterCount', format(TempFilterList.Count()));
            exit(false);
        end;

        rr.Open(Database::"PIMX Publication Line");
        fr := rr.Field(3104); // field(3104; "Data Updated On"; DateTime)
        FilterText := TempFilterList.Value;

        if not ValueHelper.ValidateExpression(FilterText, fr) then begin
            Session.LogMessage('PIMXSC102', 'Validation of "SC Last Date/Time Modified" failed', Verbosity::Warning, DataClassification::EndUserPseudonymousIdentifiers, TelemetryScope::All, 'filterText', FilterText);
            exit(false);
        end;
        exit(true);
    end;
}