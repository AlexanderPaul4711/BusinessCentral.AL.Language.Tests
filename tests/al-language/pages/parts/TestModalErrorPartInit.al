// BC Documentation: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/triggers-auto/page/devenv-oninit-page-trigger
// Scope: observe-only bootstrap. Logical state/trigger sequence, not allocation identity.
// Fixtures used: Probe Observer, PAG Modal Writes Host/Line/Log.
// local object: its OnInit/OnOpen/global state distinguishes default part access after a handler error.
page 92666 "PAG Failed Part Child"
{
    PageType = ListPart;
    SourceTable = "PAG Modal Writes Line";
    layout { area(Content) { repeater(Rows) { field(Value; Rec.Value) { ApplicationArea = All; } } } }
    trigger OnInit()
    begin InitCount += 1; L.Mark('Q.INIT'); end;
    trigger OnOpenPage()
    begin OpenCount += 1; L.Mark('Q.OPEN'); end;
    trigger OnAfterGetRecord()
    begin L.Mark('Q.AGR'); end;
    trigger OnAfterGetCurrRecord()
    begin L.Mark('Q.AGCR'); end;
    var InitCount: Integer; OpenCount: Integer; L: Codeunit "PAG Modal Writes Log";
    procedure ReadState(): Text
    begin exit(Format(InitCount) + '/' + Format(OpenCount) + '/' + Format(Rec.Id) + '/' + Rec.Value); end;
}
// local object: handler error after this host opens is the lifecycle under test.
page 92667 "PAG Failed Part Host"
{
    PageType = Card;
    SourceTable = "PAG Modal Writes Host";
    layout { area(Content) {
        field(Id; Rec.Id) { ApplicationArea = All; }
        part(Child; "PAG Failed Part Child") { ApplicationArea = All; SubPageLink = Id = field(Id); }
    } }
    trigger OnOpenPage()
    var L: Codeunit "PAG Modal Writes Log";
    begin L.Mark('R.OPEN'); end;
    procedure ReadChild(): Text
    begin exit(CurrPage.Child.Page.ReadState()); end;
}
