// BC Documentation: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/page/page-close-method
// Source-only observation bootstrap: no close deferral or post-close availability is assumed.
// local object: the parent/part lifecycle and temporary row shape are the subject of this probe.
table 97790 "PAG Trigger Close Row"
{
    DataClassification = SystemMetadata;
    fields { field(1; Id; Integer) { } }
    keys { key(PK; Id) { Clustered = true; } }
}

// local object: a dedicated trace/config is isolated to the existing parts-after-close test codeunit.
codeunit 97793 "PAG Trigger Close Log"
{
    SingleInstance = true;
    var
        Trace: Text;
        ActionMode: Boolean;
        RequestClose: Boolean;
        PermitClose: Boolean;
        Queries: Integer;
        ObservationCase: Text;
        Detailed: Boolean;
        AgcrCalls: Integer;

    procedure Reset()
    begin
        Trace := '';
        ActionMode := false;
        RequestClose := false;
        PermitClose := true;
        Queries := 0;
        ObservationCase := '';
        Detailed := false;
        AgcrCalls := 0;
    end;

    procedure EnableDetails()
    begin
        Detailed := true;
    end;

    procedure NoteAgcr()
    begin
        if Detailed then
            AgcrCalls += 1;
    end;

    procedure AgcrCount(): Integer
    begin
        exit(AgcrCalls);
    end;

    procedure Detail(Phase: Text; ParentId: Integer; AlreadyProbed: Boolean)
    begin
        if Detailed then
            Mark('D:' + Phase + ':id=' + Format(ParentId) +
                ':agcr=' + Format(AgcrCalls) + ':q=' + Format(Queries) +
                ':probed=' + Format(AlreadyProbed));
    end;

    procedure Configure(FromAction: Boolean; CloseRequested: Boolean; CloseAllowed: Boolean)
    begin
        ActionMode := FromAction;
        RequestClose := CloseRequested;
        PermitClose := CloseAllowed;
    end;

    procedure Mark(Marker: Text)
    begin
        Trace += Marker + ';';
    end;

    procedure ReadTrace(): Text
    begin
        exit(Trace);
    end;

    procedure FromAction(): Boolean
    begin
        exit(ActionMode);
    end;

    procedure ShouldClose(): Boolean
    begin
        exit(RequestClose);
    end;

    procedure AllowClose(): Boolean
    begin
        exit(PermitClose);
    end;

    procedure QuerySeen(CloseAction: Action)
    begin
        Queries += 1;
        Mark('PARENT.QUERY:' + Format(CloseAction));
    end;

    procedure SetCase(Identity: Text)
    begin
        ObservationCase := Identity;
    end;

    procedure ReadCase(): Text
    begin
        exit(ObservationCase);
    end;

    procedure QueryCount(): Integer
    begin
        exit(Queries);
    end;
}

// local object: the part exposes an actual AL method reached through CurrPage.PartBody.Page.
page 97792 "PAG Trigger Close Part"
{
    PageType = ListPart;
    SourceTable = "PAG Trigger Close Row";
    SourceTableTemporary = true;
    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field(ProbeId; Rec.Id) { ApplicationArea = All; }
            }
        }
    }
    var
        Log: Codeunit "PAG Trigger Close Log";
        State: Integer;

    trigger OnInit()
    begin
        State := 17;
        Log.Mark('PART.INIT');
    end;

    trigger OnOpenPage()
    begin
        State := 41;
        Log.Mark('PART.OPEN');
        if Rec.IsEmpty() then begin
            Rec.Init();
            Rec.Id := 1;
            Rec.Insert(false);
        end;
    end;

    trigger OnClosePage()
    begin
        State += 1000;
        Log.Mark('PART.CLOSE');
    end;

    procedure Touch(): Text
    begin
        State += 1;
        Log.Mark('PART.TOUCH:' + Format(State) + ':' + Format(Rec.Id));
        exit(Format(State) + ':' + Format(Rec.Id));
    end;
}

// local object: measures Close followed by a part call in AGCR versus an already-open OnAction context.
page 97791 "PAG Trigger Close Parent"
{
    PageType = Card;
    SourceTable = "PAG Trigger Close Row";
    SourceTableTemporary = true;
    layout
    {
        area(Content)
        {
            field(ProbeId; Rec.Id) { ApplicationArea = All; }
            part(PartBody; "PAG Trigger Close Part") { ApplicationArea = All; }
        }
    }
    actions
    {
        area(Processing)
        {
            action(ProbeAction)
            {
                ApplicationArea = All;
                trigger OnAction()
                begin
                    Log.Mark('PARENT.ACTION');
                    RunProbe();
                end;
            }
        }
    }
    var
        Log: Codeunit "PAG Trigger Close Log";
        Probed: Boolean;

    trigger OnOpenPage()
    begin
        Log.Detail('OPEN.before', Rec.Id, Probed);
        Log.Mark('PARENT.OPEN');
        if Rec.IsEmpty() then begin
            Rec.Init();
            Rec.Id := 1;
            Rec.Insert(false);
        end;
        Log.Detail('OPEN.after', Rec.Id, Probed);
    end;

    trigger OnAfterGetCurrRecord()
    begin
        Log.NoteAgcr();
        Log.Detail('AGCR.entry', Rec.Id, Probed);
        if Probed or Log.FromAction() then
            exit;
        Probed := true;
        Log.Mark('PARENT.AGCR');
        RunProbe();
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        Log.QuerySeen(CloseAction);
        Log.Detail('QUERY.entry:' + Format(CloseAction), Rec.Id, Probed);
        Log.Detail('QUERY.return:' + Format(Log.AllowClose()), Rec.Id, Probed);
        exit(Log.AllowClose());
    end;

    trigger OnClosePage()
    begin
        Log.Detail('CLOSE.entry', Rec.Id, Probed);
        Log.Mark('PARENT.CLOSE');
    end;

    local procedure RunProbe()
    var
        Reply: Text;
    begin
        if Log.ShouldClose() then begin
            Log.Detail('CALL.CLOSE.before', Rec.Id, Probed);
            Log.Mark('BEFORE.CLOSE');
            CurrPage.Close();
            Log.Mark('AFTER.CLOSE');
            Log.Detail('CALL.CLOSE.after', Rec.Id, Probed);
        end else
            Log.Mark('NO.CLOSE');
        Log.Detail('PART.before', Rec.Id, Probed);
        Log.Mark('BEFORE.PART');
        Reply := CurrPage.PartBody.Page.Touch();
        Log.Mark('AFTER.PART:' + Reply);
        Log.Detail('PART.after:' + Reply, Rec.Id, Probed);
    end;
}
