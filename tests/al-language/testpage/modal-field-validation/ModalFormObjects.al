// BC Documentation: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/testfield/testfield-setvalue-method
// local object: the table/page validation triggers, ListPlus shape and save/close vetoes are the measured contract.
// Observe-only fixture. No native outcome is asserted until measured.
table 69990 "PAG Modal Form Row"
{
    DataClassification = SystemMetadata;
    fields
    {
        field(1; Id; Integer) { }
        field(2; Value; Text[30])
        {
            trigger OnValidate()
            var L: Codeunit "PAG Modal Form Log"; Side: Record "PAG Modal Form Row";
            begin
                L.Add('table.validate:' + Value);
                Side.Get(2); Side.Note := 'side-' + Value; Side.Modify(false);
                if L.Mode() = 5 then begin
                    Commit();
                    Error('modal form committed validation failure');
                end;
                if L.Mode() = 4 then Error('modal form validation failure');
            end;
        }
        field(3; Note; Text[50]) { }
    }
    keys { key(PK; Id) { Clustered = true; } }
    trigger OnModify()
    var L: Codeunit "PAG Modal Form Log";
    begin L.Add('table.modify:' + Format(Id) + ':' + Value); end;
}
codeunit 69990 "PAG Modal Form Log"
{
    SingleInstance = true;
    var Entries: Text; SelectedMode: Integer; CloseVeto: Boolean;
    procedure Configure(NewMode: Integer)
    begin Entries := ''; SelectedMode := NewMode; CloseVeto := NewMode = 3; end;
    procedure Mode(): Integer
    begin exit(SelectedMode); end;
    procedure Add(Entry: Text)
    begin Entries += Entry + ';'; end;
    procedure ReadTrace(): Text
    begin exit(Entries); end;
    procedure QueryAllowed(): Boolean
    begin exit(not CloseVeto); end;
    procedure AllowClose()
    begin CloseVeto := false; end;
}
page 69990 "PAG Modal Form ListPlus"
{
    PageType = ListPlus;
    SourceTable = "PAG Modal Form Row";
    InsertAllowed = false;
    DeleteAllowed = false;
    layout
    {
        area(Content)
        {
            group(Fields)
            {
                field(Id; Rec.Id) { ApplicationArea = All; Editable = false; }
                field(Value; Rec.Value)
                {
                    ApplicationArea = All;
                    trigger OnValidate()
                    var L: Codeunit "PAG Modal Form Log";
                    begin
                        L.Add('page.validate:' + Rec.Value);
                        if L.Mode() = 1 then CurrPage.SaveRecord();
                    end;
                }
                field(Note; Rec.Note) { ApplicationArea = All; }
                field(Hidden; Rec.Note) { ApplicationArea = All; Visible = false; }
                field(Locked; Rec.Note) { ApplicationArea = All; Editable = false; }
                field(Disabled; Rec.Note) { ApplicationArea = All; Enabled = false; }
            }
        }
    }
    trigger OnModifyRecord(): Boolean
    var L: Codeunit "PAG Modal Form Log";
    begin L.Add('page.modify:' + Rec.Value); exit(L.Mode() <> 2); end;
    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var L: Codeunit "PAG Modal Form Log";
    begin L.Add('page.query:' + Format(CloseAction)); exit(L.QueryAllowed()); end;
    trigger OnClosePage()
    var L: Codeunit "PAG Modal Form Log";
    begin L.Add('page.close'); end;
}
