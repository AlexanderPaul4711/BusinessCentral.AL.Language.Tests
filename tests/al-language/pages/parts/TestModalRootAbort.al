// BC Documentation: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/triggers-auto/page/devenv-oninit-page-trigger
// Scope: logical root/part state at four observed modal boundaries, not allocation identity or a universal error policy.
// local object: prepared globals and separate lifecycle counters expose root state before any part getter.
page 92671 "PAG Modal Root Abort"
{
    PageType = List;
    SourceTable = "PAG Modal Writes Host";
    layout { area(Content) {
        repeater(Rows) { field(Id; Rec.Id) { ApplicationArea = All; } field(Value; Rec.Value) { ApplicationArea = All; } }
        part(Child; "PAG Failed Part Child") { ApplicationArea = All; SubPageLink = Id = field(Id); }
    } }
    trigger OnInit()
    begin InitCount += 1; Tag := 'initialized'; L.Mark('RR.INIT'); end;
    trigger OnOpenPage()
    begin OpenCount += 1; Tag := 'opened'; L.Mark('RR.OPEN'); end;
    trigger OnAfterGetCurrRecord()
    begin
        L.Mark('RR.AGCR.' + Format(Rec.Id));
        if (L.ReadPhase() = 'row-error-armed') and (Rec.Id = L.RowId() + 1) then begin
            L.Mark('RR.ROW.ERROR'); Error('root row handler failure');
        end;
    end;
    var InitCount: Integer; OpenCount: Integer; Tag: Text; L: Codeunit "PAG Modal Writes Log";
    procedure Prepare() begin Tag := 'prepared'; end;
    procedure ReadRoot(): Text
    begin exit(Format(InitCount) + '/' + Format(OpenCount) + '/' + Tag + '/' + Format(Rec.Id) + '/' + Rec.Value); end;
    procedure ReadChild(): Text begin exit(CurrPage.Child.Page.ReadState()); end;
}
