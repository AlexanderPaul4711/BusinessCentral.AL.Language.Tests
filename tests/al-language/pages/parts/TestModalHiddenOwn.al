// BC Documentation: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/page/page-update-method
// Scope: three own-call observations after a previously visible part is hidden, then its owner closes.
// No retained external child-alias or mixed child-close-trigger ordering claim.
// local object: its distinct trace proves whether the hidden child's view refreshes or saves.
page 92668 "PAG Hidden Return A"
{
    PageType = ListPart; SourceTable = "PAG Modal Writes Line";
    layout { area(Content) { repeater(Rows) { field(Id; Rec.Id) { ApplicationArea = All; } field(Value; Rec.Value) { ApplicationArea = All; } } } }
    trigger OnInit() begin L.Mark('HA.INIT'); end;
    trigger OnOpenPage() begin L.Mark('HA.OPEN'); end;
    trigger OnAfterGetRecord() begin L.Mark('HA.AGR'); end;
    trigger OnAfterGetCurrRecord() begin L.Mark('HA.AGCR'); end;
    trigger OnModifyRecord(): Boolean begin L.Mark('HA.PAGE.MODIFY'); exit(true); end;
    var L: Codeunit "PAG Modal Writes Log";
    procedure Dirty() begin Rec.Value := 'part-dirty'; L.Mark('HA.DIRTY'); end;
    procedure Snapshot(): Text
    var Fresh: Record "PAG Modal Writes Line";
    begin
        if Fresh.Get(L.RowId()) then exit(Format(Rec.Id) + ':' + Rec.Value + '/db@' + Format(L.RowId()) + ':' + Fresh.Value);
        exit(Format(Rec.Id) + ':' + Rec.Value + '/MISSING');
    end;
    procedure Operate(Op: Integer)
    begin
        case Op of 0: CurrPage.Update(false); 1: CurrPage.Update(true); 2: CurrPage.SaveRecord(); end;
    end;
}
// local object: independently labelled visible-sibling trace and held record.
page 92669 "PAG Hidden Return B"
{
    PageType = ListPart; SourceTable = "PAG Modal Writes Line";
    layout { area(Content) { repeater(Rows) { field(Id; Rec.Id) { ApplicationArea = All; } field(Value; Rec.Value) { ApplicationArea = All; } } } }
    trigger OnInit() begin L.Mark('HB.INIT'); end;
    trigger OnOpenPage() begin L.Mark('HB.OPEN'); end;
    trigger OnAfterGetRecord() begin L.Mark('HB.AGR'); end;
    trigger OnAfterGetCurrRecord() begin L.Mark('HB.AGCR'); end;
    var L: Codeunit "PAG Modal Writes Log";
    procedure Snapshot(): Text
    var Fresh: Record "PAG Modal Writes Line";
    begin
        if Fresh.Get(L.RowId()) then exit(Format(Rec.Id) + ':' + Rec.Value + '/db@' + Format(L.RowId()) + ':' + Fresh.Value);
        exit(Format(Rec.Id) + ':' + Rec.Value + '/MISSING');
    end;
}
// local object: an actual A-to-B visibility transition precedes modal close.
page 92670 "PAG Hidden Return Host"
{
    PageType = Card; SourceTable = "PAG Modal Writes Host";
    layout { area(Content) {
        field(Id; Rec.Id) { ApplicationArea = All; }
        field(ShowB; ShowB) {
            ApplicationArea = All;
            trigger OnValidate() begin VisibleA := not ShowB; VisibleB := ShowB; end;
        }
        part(A; "PAG Hidden Return A") { ApplicationArea = All; SubPageLink = Id = field(Id); Visible = VisibleA; }
        part(B; "PAG Hidden Return B") { ApplicationArea = All; SubPageLink = Id = field(Id); Visible = VisibleB; }
    } }
    trigger OnOpenPage() begin VisibleA := true; VisibleB := false; L.Mark('HP.OPEN'); end;
    trigger OnAfterGetRecord() begin L.Mark('HP.AGR'); end;
    trigger OnAfterGetCurrRecord() begin L.Mark('HP.AGCR'); end;
    trigger OnClosePage() begin L.Mark('HP.CLOSE'); end;
    var L: Codeunit "PAG Modal Writes Log"; ShowB: Boolean; VisibleA: Boolean; VisibleB: Boolean;
    procedure HiddenSnapshot(): Text begin exit(CurrPage.A.Page.Snapshot()); end;
    procedure VisibleSnapshot(): Text begin exit(CurrPage.B.Page.Snapshot()); end;
    procedure DirtyHidden() begin CurrPage.A.Page.Dirty(); end;
    procedure OperateHidden(Op: Integer) begin CurrPage.A.Page.Operate(Op); end;
}
