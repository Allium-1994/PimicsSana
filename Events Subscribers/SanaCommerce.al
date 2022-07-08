codeunit 82530 "PIMX SC Subscriber"
{
    SingleInstance = true;

    var
        lang: Integer;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"SC - Product Functions", 'OnBeforeGetProducts', '', true, true)]
    local procedure SCProduct_OnBeforeGetProducts(var XMLNodeBuff: Record "SC - XML Buffer (dotNET)"; var Item: Record Item; var Params: Record "SC - Parameters Collection");
    var
        publLine: Record "PIMX Publication Line";
        publHeader: Record "PIMX Publication Header";
        log: Codeunit "PIMX Activity Log Management";
        DateFilter, ItemNoFilter : Text;
        lock, selected : List of [Text];
        step, _Count, Position : Integer;
        publQuery: Query "PIMX SC Items or Groups";
        PimLog_lbl: Label 'OnBeforeGetProducts: P=%1 C=%2', Locked = true;
        Dimensions: Dictionary of [Text, Text];
        Start: DateTime;
        Duration: Duration;
    begin
        Start := CurrentDateTime();
        log.SaveMessage('PIMSC001', "PIMX Activity Log Type"::"Debug Message", Codeunit::"PIMX SC Subscriber", ObjectType::Codeunit, 'OnBeforeGetProducts: Params for ' + Params.WebsiteId, StrSubstNo('Item Filters:\%1\Params:\PageIndex:%3\PageSize:%4\VisibleOnly:%5\%2', Item.GetFilters(), ParamsToText(Params), Params.PageIndex, Params.PageSize, Params.VisibleOnly));

        if not publHeader.GetByExternalCode(Params.WebsiteId) then
            exit;

        ItemNoFilter := GetNoFilter(Item, Params);
        DateFilter := GetDateFilter(Item, Params);
        if DateFilter = '' then
            exit;

        //Dimensions       
        Dimensions.Add('itemFilter', Item.GetFilters());
        Dimensions.Add('websiteId', Params.WebsiteId);
        Dimensions.Add('params', ParamsToText(Params));
        Dimensions.Add('itemNoFilter', ItemNoFilter);
        Dimensions.Add('dateFilter', DateFilter);

        //Find changes in publication when we have filter for datetime
        if DateFilter <> '*' then begin
            Item.SetFilter("Last DateTime Modified", DateFilter);
            if ItemNoFilter <> '' then
                Item.SetFilter("Last DateTime Modified", ItemNoFilter);
            _Count := MarkAll(Item);
            Dimensions.Add('defaultItemCount', format(_Count));
            Item.SetRange("Last DateTime Modified");

            for step := 1 to 2 do begin
                publQuery.SetRange(item_Zeilenart, publLine.Zeilenart::Artikel); //
                publQuery.SetRange(item_Code, publHeader.Code);
                case step of
                    1:
                        publQuery.SetFilter(data_Data_Updated_On, DateFilter);
                    2:
                        publQuery.SetFilter(item_Data_Updated_On, DateFilter);
                end;
                if publQuery.Open() then
                    while publQuery.Read() do
                        if not lock.Contains(publQuery.item_Nummer) then begin
                            if ItemNoFilter <> '' then
                                Item.SetFilter("No.", StrSubstNo('%1&(%2)', publQuery.item_Nummer, ItemNoFilter))
                            else
                                Item.SetRange("No.", publQuery.item_Nummer);
                            if Item.FINDFIRST() then begin
                                Item.Mark(true);
                                selected.Add(publQuery.item_Nummer);
                            end;
                            //Session.LogMessage('DEBUG', 'FINDFIRST ' + format(Item.FINDFIRST()), Verbosity::Normal, DataClassification::OrganizationIdentifiableInformation, TelemetryScope::All, 'Item.GetFilters()', Item.GetFilters());
                            lock.Add(publQuery.item_Nummer);
                        end;
            end;

            if (Params.PageIndex <> 0) and (Params.PageSize <> 0) then
                Position := Params.PageIndex * Params.PageSize;
            Position := Position + Params.PageSize;

            //Mark only current page
            item.SetRange("No.");
            Item.MarkedOnly(true);
        end;
        _Count := Item.Count();
        Duration := CurrentDateTime() - Start;

        Dimensions.Add('itemTotalCount', format(_Count));
        Dimensions.Add('pageIndex', format(Params.PageIndex));
        Dimensions.Add('pageSize', format(Params.PageSize));
        Dimensions.Add('duration', format(Duration, 9));
        Session.LogMessage('PIMXSC101', 'OnBeforeGetProducts is done', Verbosity::Normal, DataClassification::OrganizationIdentifiableInformation, TelemetryScope::All, Dimensions);
        log.SaveMessage('PIMXSC101', "PIMX Activity Log Type"::"Debug Message", Codeunit::"PIMX SC Subscriber", ObjectType::Codeunit, StrSubstNo(PimLog_lbl, Params.WebsiteId, _Count), StrSubstNo('Count: %1\Duration: %2\Position: %3\Filter Date: %4\Filter Item No: %5\Selected ItemIds: %6', _Count, Duration, Position, DateFilter, ItemNoFilter, ListToText(selected)));
    end;

    local procedure MarkAll(var Item: Record Item) _Count: Integer
    begin
        if Item.FindSet() then
            repeat
                Item.Mark(true);
                _Count += 1;
            until Item.Next() = 0;
    end;

    local procedure GetNoFilter(var Item: Record Item; var Params: Record "SC - Parameters Collection") FilterText: Text
    begin
        FilterText := Item.GetFilter("No.");
        if FilterText = '' then
            FilterText := Params.GetFilterListValue('No.')
    end;

    local procedure GetDateFilter(var Item: Record Item; var Params: Record "SC - Parameters Collection") FilterText: Text
    begin
        FilterText := Item.GetFilter("Last DateTime Modified");
        if FilterText = '' then
            if not GetDateFilter(Params, FilterText) then
                FilterText := '';
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
            Session.LogMessage('PIMXSC102', 'Missing parameter "SC Last Date/Time Modified"', Verbosity::Warning, DataClassification::OrganizationIdentifiableInformation, TelemetryScope::All, 'filterCount', format(TempFilterList.Count()), 'langauge', format(GlobalLanguage()));
            exit(false);
        end;

        if ValueHelper.IsRebuildIndexFilter(TempFilterList) then begin
            FilterText := '*';
            exit(true);
        end;

        rr.Open(Database::"PIMX Publication Line");
        fr := rr.Field(3104); // field(3104; "Data Updated On"; DateTime)
        FilterText := TempFilterList.Value;

        if not ValueHelper.ValidateExpression(FilterText, fr) then begin
            Session.LogMessage('PIMXSC102', 'Validation of "SC Last Date/Time Modified" failed', Verbosity::Warning, DataClassification::OrganizationIdentifiableInformation, TelemetryScope::All, 'filterText', FilterText, 'langauge', format(GlobalLanguage()));
            exit(false);
        end;
        exit(true);
    end;

    local procedure ListToText(items: List of [Text]): Text
    var
        tb: TextBuilder;
        i: Text;
    begin
        foreach i in items do begin
            if tb.Length > 0 then
                tb.Append('|' + i)
            else
                tb.Append(i);
        end;
        exit(tb.ToText());
    end;

    local procedure ParamsToText(var Params: Record "SC - Parameters Collection"): Text
    var
        tb: TextBuilder;
        TempFilterList: Record "SC - Key Value" temporary;
    begin
        Params.GetFilterList(TempFilterList);
        if TempFilterList.FindSet() then
            repeat
                tb.Append(StrSubstNo('%1: %2\', TempFilterList."Key", TempFilterList.Value));
            until TempFilterList.Next() = 0;
        exit(tb.ToText());
    end;
}