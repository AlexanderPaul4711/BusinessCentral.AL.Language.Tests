// BC Documentation: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-events-in-al
// local object: page/extension action definitions without bodies and their generated-event subscribers are the measured shape.
// Shared row: ALT Universal. The SingleInstance trace has no database side effects of its own.
codeunit 69992 "PAG EventOnly Log"
{
    SingleInstance = true;
    var Entries: Text; FailurePhase: Text; RequestedWritePhase: Text; CommitRequested: Boolean;
    procedure Reset() begin Entries := ''; FailurePhase := ''; RequestedWritePhase := ''; CommitRequested := false; end;
    procedure RequestWrite(Phase: Text; WithCommit: Boolean) begin RequestedWritePhase := Phase; CommitRequested := WithCommit; end;
    procedure ShouldWrite(Phase: Text): Boolean begin exit(RequestedWritePhase = Phase); end;
    procedure ShouldCommit(): Boolean begin exit(CommitRequested); end;
    procedure FailAt(Phase: Text) begin FailurePhase := Phase; end;
    procedure CheckFailure(Phase: Text) begin if Phase = FailurePhase then Error('event-only subscriber failure: %1', Phase); end;
    procedure Add(Entry: Text) begin Entries += Entry + ';'; end;
    procedure ReadTrace(): Text begin exit(Entries); end;
}
page 69992 "PAG EventOnly Page"
{
    PageType = Card;
    SourceTable = "ALT Universal";
    layout { area(Content) { group(Fields) { field(Number; Rec."Integer Field") { ApplicationArea = All; } } } }
    actions
    {
        area(Processing)
        {
            action(BaseAfter) { ApplicationArea = All; Caption = 'Base after only'; }
            action(BaseBoth) { ApplicationArea = All; Caption = 'Base before and after'; }
            action(NoSubscriber) { ApplicationArea = All; Caption = 'No subscriber'; }
            action(Normal)
            {
                ApplicationArea = All;
                trigger OnAction()
                var L: Codeunit "PAG EventOnly Log";
                begin L.Add('normal.body:' + Format(Rec."Integer Field")); Rec."Integer Field" += 11; end;
            }
        }
    }
    trigger OnOpenPage()
    var L: Codeunit "PAG EventOnly Log";
    begin L.Add('open'); end;
    trigger OnClosePage()
    var L: Codeunit "PAG EventOnly Log";
    begin L.Add('close'); end;
}
pageextension 69992 "PAG EventOnly Extension" extends "LT AO Dep Card"
{
    actions { addlast(Processing) {
        action(ExtensionAfter) { ApplicationArea = All; Caption = 'Extension after only'; }
        action(ExtensionBoth) { ApplicationArea = All; Caption = 'Extension before and after'; }
    } }
}
page 69996 "PAG EventOnly ListPart"
{
    PageType = ListPart;
    SourceTable = "ALT Universal";
    layout { area(Content) { repeater(Rows) { field(Number; Rec."Integer Field") { ApplicationArea = All; } } } }
    actions { area(Processing) { action(PartAfter) { ApplicationArea = All; Caption = 'Part after only'; } } }
}
page 69995 "PAG EventOnly Part Host"
{
    PageType = Card;
    SourceTable = "ALT Universal";
    layout { area(Content) {
        field(Entry; Rec."Entry No.") { ApplicationArea = All; }
        part(Lines; "PAG EventOnly ListPart") { ApplicationArea = All; SubPageLink = "Entry No." = field("Entry No."); }
    } }
}
codeunit 69993 "PAG EventOnly Subscribers"
{
    [EventSubscriber(ObjectType::Page, Page::"PAG EventOnly Page", 'OnAfterActionEvent', 'BaseAfter', false, false)]
    local procedure BaseAfter(var Rec: Record "ALT Universal")
    begin Touch('base.after', Rec, 7); end;
    [EventSubscriber(ObjectType::Page, Page::"PAG EventOnly Page", 'OnBeforeActionEvent', 'BaseBoth', false, false)]
    local procedure BaseBothBefore(var Rec: Record "ALT Universal")
    begin Touch('both.before', Rec, 3); end;
    [EventSubscriber(ObjectType::Page, Page::"PAG EventOnly Page", 'OnAfterActionEvent', 'BaseBoth', false, false)]
    local procedure BaseBothAfter(var Rec: Record "ALT Universal")
    begin Touch('both.after', Rec, 7); end;
    [EventSubscriber(ObjectType::Page, Page::"LT AO Dep Card", 'OnAfterActionEvent', 'ExtensionAfter', false, false)]
    local procedure ExtensionAfter(var Rec: Record "LT AO Dep Row")
    begin TouchExtension('extension.after', Rec, '-A'); end;
    [EventSubscriber(ObjectType::Page, Page::"LT AO Dep Card", 'OnBeforeActionEvent', 'ExtensionBoth', false, false)]
    local procedure ExtensionBothBefore(var Rec: Record "LT AO Dep Row")
    begin TouchExtension('extension.both.before', Rec, '-B'); end;
    [EventSubscriber(ObjectType::Page, Page::"LT AO Dep Card", 'OnAfterActionEvent', 'ExtensionBoth', false, false)]
    local procedure ExtensionBothAfter(var Rec: Record "LT AO Dep Row")
    begin TouchExtension('extension.both.after', Rec, '-A'); end;
    [EventSubscriber(ObjectType::Page, Page::"PAG EventOnly Page", 'OnBeforeActionEvent', 'Normal', false, false)]
    local procedure NormalBefore(var Rec: Record "ALT Universal")
    begin Touch('normal.before', Rec, 3); end;
    [EventSubscriber(ObjectType::Page, Page::"PAG EventOnly Page", 'OnAfterActionEvent', 'Normal', false, false)]
    local procedure NormalAfter(var Rec: Record "ALT Universal")
    begin Touch('normal.after', Rec, 7); end;
    [EventSubscriber(ObjectType::Page, Page::"PAG EventOnly ListPart", 'OnAfterActionEvent', 'PartAfter', false, false)]
    local procedure PartAfter(var Rec: Record "ALT Universal")
    begin Touch('part.after', Rec, 7); end;
    local procedure TouchExtension(Phase: Text; var Rec: Record "LT AO Dep Row"; Suffix: Text)
    var L: Codeunit "PAG EventOnly Log";
    begin L.Add(Phase + ':' + Format(Rec.Id) + ':' + Rec.Name); L.CheckFailure(Phase); Rec.Name += Suffix; end;
    local procedure Touch(Phase: Text; var Rec: Record "ALT Universal"; Delta: Integer)
    var L: Codeunit "PAG EventOnly Log";
    begin L.Add(Phase + ':' + Format(Rec."Entry No.") + ':' + Format(Rec."Integer Field")); L.CheckFailure(Phase); Rec."Integer Field" += Delta; if L.ShouldWrite(Phase) then begin Rec.Modify(false); if L.ShouldCommit() then Commit(); end; end;
}
