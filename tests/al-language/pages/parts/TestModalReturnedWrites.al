// BC Documentation: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/page/page-update-method
// Scope: in-scope (Cloud-compatible); exact native facts are asserted by the caller.
// Fixtures used: Probe Observer; local objects below whose page/table trigger definitions are under test.
// BC versions: 27.5/28.5/29.0. Existing Y37 cases remain unchanged.
// local object: distinguish retained page Rec, database writes and page/table trigger execution after modal return.
table 92661 "PAG Modal Writes Host"
{
    DataClassification = SystemMetadata;
    fields { field(1; Id; Integer) { } field(2; Value; Text[30]) { } }
    keys { key(PK; Id) { Clustered = true; } }
    trigger OnModify()
    var L: Codeunit "PAG Modal Writes Log";
    begin L.Mark('H.TABLE.MODIFY'); end;
}
// local object: independently read the actual part record and its write trigger.
table 92662 "PAG Modal Writes Line"
{
    DataClassification = SystemMetadata;
    fields { field(1; Id; Integer) { } field(2; Value; Text[30]) { } }
    keys { key(PK; Id) { Clustered = true; } }
    trigger OnModify()
    var L: Codeunit "PAG Modal Writes Log";
    begin L.Mark('P.TABLE.MODIFY'); end;
}
// local object: its exact CurrPage Update/SaveRecord and page trigger sequence is measured.
page 92663 "PAG Modal Writes Part"
{
    PageType = ListPart;
    SourceTable = "PAG Modal Writes Line";
    layout { area(Content) { repeater(Rows) { field(Value; Rec.Value) { ApplicationArea = All; } } } }
    trigger OnAfterGetRecord()
    begin L.Mark('P.AGR'); end;
    trigger OnAfterGetCurrRecord()
    begin L.Mark('P.AGCR'); end;
    trigger OnModifyRecord(): Boolean
    begin L.Mark('P.PAGE.MODIFY'); exit(true); end;
    var L: Codeunit "PAG Modal Writes Log";
    procedure Dirty()
    begin Rec.Value := 'part-dirty'; L.Mark('P.DIRTY'); end;
    procedure Snapshot(): Text
    var Fresh: Record "PAG Modal Writes Line";
    begin
        if Fresh.Get(L.RowId()) then exit(Format(Rec.Id) + ':' + Rec.Value + '/db@' + Format(L.RowId()) + ':' + Fresh.Value);
        exit(Format(Rec.Id) + ':' + Rec.Value + '/db@' + Format(L.RowId()) + ':MISSING');
    end;
    procedure Operate(Op: Integer)
    begin
        case Op of
            0: CurrPage.Update(false);
            1: CurrPage.Update(true);
            2: CurrPage.SaveRecord();
        end;
    end;
}
// local object: modal lifecycle and host/part method invocation are the subject.
page 92664 "PAG Modal Writes Dialog"
{
    PageType = Card;
    SourceTable = "PAG Modal Writes Host";
    layout { area(Content) {
        field(Value; Rec.Value) { ApplicationArea = All; }
        part(Lines; "PAG Modal Writes Part") { ApplicationArea = All; SubPageLink = Id = field(Id); }
    } }
    actions { area(Processing) { action(Probe) {
        ApplicationArea = All;
        trigger OnAction()
        begin
            L.ResetTrace(); Dirty(L.Side()); L.Before(Snapshot(L.Side()));
            Operate(L.Side(), L.Operation());
            L.Freeze(Snapshot(L.Side()));
        end;
    } } }
    trigger OnAfterGetRecord()
    begin L.Mark('H.AGR'); end;
    trigger OnAfterGetCurrRecord()
    begin L.Mark('H.AGCR'); end;
    trigger OnModifyRecord(): Boolean
    begin L.Mark('H.PAGE.MODIFY'); exit(true); end;
    var L: Codeunit "PAG Modal Writes Log";
    procedure Dirty(Side: Integer)
    begin
        if Side = 0 then begin Rec.Value := 'host-dirty'; L.Mark('H.DIRTY'); end
        else CurrPage.Lines.Page.Dirty();
    end;
    procedure Snapshot(Side: Integer): Text
    var Fresh: Record "PAG Modal Writes Host";
    begin
        if Side = 1 then exit(CurrPage.Lines.Page.Snapshot());
        if Fresh.Get(L.RowId()) then exit(Format(Rec.Id) + ':' + Rec.Value + '/db@' + Format(L.RowId()) + ':' + Fresh.Value);
        exit(Format(Rec.Id) + ':' + Rec.Value + '/db@' + Format(L.RowId()) + ':MISSING');
    end;
    procedure Operate(Side: Integer; Op: Integer)
    begin
        if Side = 1 then begin CurrPage.Lines.Page.Operate(Op); exit; end;
        case Op of
            0: CurrPage.Update(false);
            1: CurrPage.Update(true);
            2: CurrPage.SaveRecord();
        end;
    end;
}
// local object: freeze action-time snapshots before later modal close can save or run triggers.
codeunit 92665 "PAG Modal Writes Log"
{
    SingleInstance = true;
    var ModeValue: Integer; SideValue: Integer; OpValue: Integer; TraceValue: Text;
        PhaseValue: Text; TryOkValue: Text; TryCodeValue: Text; ReturnedValue: Text;
        BeforeValue: Text; AfterValue: Text; FrozenTrace: Text; RowIdValue: Integer; AfterInvokeValue: Text; AfterInvokeTrace: Text;
    procedure Configure(Mode: Integer; TargetSide: Integer; Op: Integer; ExpectedRowId: Integer)
    begin ModeValue := Mode; SideValue := TargetSide; OpValue := Op;
        PhaseValue := ''; TryOkValue := ''; TryCodeValue := ''; ReturnedValue := '';
        BeforeValue := ''; AfterValue := ''; FrozenTrace := ''; TraceValue := '';
        RowIdValue := ExpectedRowId; AfterInvokeValue := ''; AfterInvokeTrace := ''; end;
    procedure Phase(Value: Text) begin PhaseValue := Value; end;
    procedure ReadPhase(): Text begin exit(PhaseValue); end;
    procedure TryResult(Ok: Text; Code: Text) begin TryOkValue := Ok; TryCodeValue := Code; end;
    procedure TryOkText(): Text begin exit(TryOkValue); end;
    procedure TryCodeText(): Text begin exit(TryCodeValue); end;
    procedure Returned(Value: Text) begin ReturnedValue := Value; end;
    procedure ReturnedText(): Text begin exit(ReturnedValue); end;
    procedure RowId(): Integer begin exit(RowIdValue); end;
    procedure AfterInvoke(Value: Text; Trace: Text) begin AfterInvokeValue := Value; AfterInvokeTrace := Trace; end;
    procedure AfterInvokeText(): Text begin exit(AfterInvokeValue); end;
    procedure AfterInvokeTraceText(): Text begin exit(AfterInvokeTrace); end;
    procedure Mode(): Integer begin exit(ModeValue); end;
    procedure Side(): Integer begin exit(SideValue); end;
    procedure Operation(): Integer begin exit(OpValue); end;
    procedure Mark(Value: Text) begin TraceValue += Value + ';'; end;
    procedure ResetTrace() begin TraceValue := ''; end;
    procedure ReadTrace(): Text begin exit(TraceValue); end;
    procedure Before(Value: Text) begin BeforeValue := Value; end;
    procedure Freeze(Value: Text) begin AfterValue := Value; FrozenTrace := TraceValue; end;
    procedure BeforeText(): Text begin exit(BeforeValue); end;
    procedure AfterText(): Text begin exit(AfterValue); end;
    procedure OperationTrace(): Text begin exit(FrozenTrace); end;
}
