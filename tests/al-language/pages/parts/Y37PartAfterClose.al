// BC Documentation: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/page/page-runmodal-method
// Scope: in-scope
// Fixtures used: Probe Observer (codeunit 69160); self-contained objects 92643 - 92648
// Probe: gap cycle 3 spec C3-14. A dialog with two line parts behind Visible variables, opened by Page.RunModal on a Page variable
//   (LookupMode); after RunModal returned, a procedure of the dialog reaches a part through CurrPage.<part>.Page and the part copies its
//   Rec and calls CurrPage.SetSelectionFilter (the shape of a "get posted document lines" dialog). Also CurrPage.Update / SaveRecord and a
//   part's CurrPage.Update called by the dialog's code after it closed. Every literal asserted below is what the BC service tier produced.
// Facts: the record the part hands out after the dialog closed (OK, Cancel, a moved part row, the other part shown by an option control),
//   on a dialog that never ran, and after Page.Run closed; ok or the error text and code of Update / SaveRecord after close.
// BC versions: 27, 28, 29

table 92643 "LT Y37 PC Vend"
{
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "No."; Code[20]) { }
        field(2; Name; Text[30]) { }
    }

    keys
    {
        key(PK; "No.") { Clustered = true; }
    }
}

table 92644 "LT Y37 PC Line"
{
    DataClassification = SystemMetadata;

    fields
    {
        field(1; Vend; Code[20]) { }
        field(2; "Line No."; Integer) { }
        field(3; Kind; Integer) { }
        field(4; Descr; Text[30]) { }
    }

    keys
    {
        key(PK; Vend, "Line No.") { Clustered = true; }
    }
}

page 92645 "LT Y37 PC Part A"
{
    PageType = ListPart;
    SourceTable = "LT Y37 PC Line";
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field("Line No."; Rec."Line No.") { ApplicationArea = All; }
                field(Descr; Rec.Descr) { ApplicationArea = All; }
            }
        }
    }

    procedure GetSelectedLine(var L: Record "LT Y37 PC Line")
    begin
        L.Copy(Rec);
        CurrPage.SetSelectionFilter(L);
    end;

    procedure PartUpdate()
    begin
        CurrPage.Update(false);
    end;

    procedure RecText(): Text
    begin
        exit(Rec.Vend + '/' + Format(Rec."Line No.") + ' filters [' + Rec.GetFilters() + ']');
    end;
}

page 92646 "LT Y37 PC Part B"
{
    PageType = ListPart;
    SourceTable = "LT Y37 PC Line";
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field("Line No."; Rec."Line No.") { ApplicationArea = All; }
                field(Descr; Rec.Descr) { ApplicationArea = All; }
            }
        }
    }

    procedure GetSelectedLine(var L: Record "LT Y37 PC Line")
    begin
        L.Copy(Rec);
        CurrPage.SetSelectionFilter(L);
    end;
}

page 92647 "LT Y37 PC Dialog"
{
    PageType = Card;
    SourceTable = "LT Y37 PC Vend";
    ApplicationArea = All;
    UsageCategory = None;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            field("No."; Rec."No.") { ApplicationArea = All; Editable = false; }
            field(MenuOpt; MenuOpt)
            {
                ApplicationArea = All;
                trigger OnValidate()
                begin
                    ChangeMenu(MenuOpt);
                end;
            }
            part(PartA; "LT Y37 PC Part A")
            {
                ApplicationArea = All;
                SubPageLink = Vend = field("No.");
                SubPageView = where(Kind = const(0));
                Visible = VisA;
            }
            part(PartB; "LT Y37 PC Part B")
            {
                ApplicationArea = All;
                SubPageLink = Vend = field("No.");
                SubPageView = where(Kind = const(1));
                Visible = VisB;
            }
        }
    }

    trigger OnOpenPage()
    begin
        ChangeMenu(MenuOpt::x0);
    end;

    var
        MenuOpt: Option x0,x1;
        CurrentMenu: Integer;
        VisA: Boolean;
        VisB: Boolean;

    local procedure ChangeMenu(NewMenu: Integer)
    begin
        VisA := NewMenu = 0;
        VisB := NewMenu = 1;
        CurrentMenu := NewMenu;
    end;

    procedure GetCurrentMenu(): Integer
    begin
        exit(CurrentMenu);
    end;

    procedure CopySel(Menu: Integer; var L: Record "LT Y37 PC Line")
    begin
        case Menu of
            0:
                CurrPage.PartA.Page.GetSelectedLine(L);
            1:
                CurrPage.PartB.Page.GetSelectedLine(L);
        end;
    end;

    procedure PartARecText(): Text
    begin
        exit(CurrPage.PartA.Page.RecText());
    end;

    procedure HostUpdate(Save: Boolean)
    begin
        CurrPage.Update(Save);
    end;

    procedure HostSaveRecord()
    begin
        CurrPage.SaveRecord();
    end;

    procedure PartAUpdate()
    begin
        CurrPage.PartA.Page.PartUpdate();
    end;
}

codeunit 92648 "LT Y37 PC Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Observer: Codeunit "Probe Observer";
        HandlerMode: Integer;

    local procedure Seed(var V: Record "LT Y37 PC Vend")
    var
        L: Record "LT Y37 PC Line";
    begin
        V.DeleteAll();
        L.DeleteAll();
        V."No." := 'V2';
        V.Insert();
        AddLine('V2', 10000, 0, 'x1');
        V."No." := 'V1';
        V.Name := 'One';
        V.Insert();
        AddLine('V1', 10000, 0, 'a1');
        AddLine('V1', 20000, 0, 'a2');
        AddLine('V1', 30000, 1, 'b1');
        AddLine('V1', 40000, 1, 'b2');
    end;

    local procedure AddLine(Vend: Code[20]; LineNo: Integer; Kind: Integer; Descr: Text[30])
    var
        L: Record "LT Y37 PC Line";
    begin
        L.Vend := Vend;
        L."Line No." := LineNo;
        L.Kind := Kind;
        L.Descr := Descr;
        L.Insert();
    end;

    local procedure Lines(var L: Record "LT Y37 PC Line"): Text
    var
        T: Text;
    begin
        if L.FindSet() then
            repeat
                T += Format(L."Line No.") + ';';
            until L.Next() = 0;
        exit(T);
    end;

    // Copies the selection of part Menu into a record and observes its count, filters and rows; an error is observed instead.
    local procedure ObserveSel(Name: Text; var Pg: Page "LT Y37 PC Dialog"; Menu: Integer)
    var
        L: Record "LT Y37 PC Line";
    begin
        ClearLastError();
        if TryCopySel(Pg, Menu, L) then begin
            Observer.Observe(Name + ' count', Format(L.Count()));
            Observer.Observe(Name + ' filters', L.GetFilters());
            Observer.Observe(Name + ' rows', Lines(L));
        end else
            Observer.ObserveError(Name + ' error');
    end;

    [TryFunction]
    local procedure TryCopySel(var Pg: Page "LT Y37 PC Dialog"; Menu: Integer; var L: Record "LT Y37 PC Line")
    begin
        Pg.CopySel(Menu, L);
    end;

    [TryFunction]
    local procedure TryHostUpdate(var Pg: Page "LT Y37 PC Dialog"; Save: Boolean)
    begin
        Pg.HostUpdate(Save);
    end;

    [TryFunction]
    local procedure TryHostSaveRecord(var Pg: Page "LT Y37 PC Dialog")
    begin
        Pg.HostSaveRecord();
    end;

    [TryFunction]
    local procedure TryPartAUpdate(var Pg: Page "LT Y37 PC Dialog")
    begin
        Pg.PartAUpdate();
    end;

    [TryFunction]
    local procedure TryPartARecText(var Pg: Page "LT Y37 PC Dialog"; var T: Text)
    begin
        T := Pg.PartARecText();
    end;

    local procedure Step(Name: Text; Ok: Boolean)
    begin
        Observer.Observe(Name, Format(Ok));
        if not Ok then
            Observer.ObserveError(Name + ' error')
        else
            ClearLastError();
    end;

    local procedure RunDialog(var Pg: Page "LT Y37 PC Dialog"; var V: Record "LT Y37 PC Vend"; Mode: Integer)
    begin
        HandlerMode := Mode;
        Pg.SetRecord(V);
        Pg.LookupMode := true;
        Observer.Observe('runmodal', Format(Pg.RunModal()));
    end;

    [ModalPageHandler]
    procedure DialogHandler(var P: TestPage "LT Y37 PC Dialog")
    begin
        case HandlerMode of
            0:
                P.OK().Invoke();
            1:
                begin
                    P.PartA.Last();
                    P.OK().Invoke();
                end;
            2:
                begin
                    P.MenuOpt.SetValue('x1');
                    P.PartB.Last();
                    P.OK().Invoke();
                end;
            3:
                P.Cancel().Invoke();
        end;
    end;

    [Test]
    [HandlerFunctions('DialogHandler')]
    procedure LT_C314_AfterRunModalOK_PartSelection()
    var
        V: Record "LT Y37 PC Vend";
        Pg: Page "LT Y37 PC Dialog";
        T: Text;
    begin
        Seed(V);
        RunDialog(Pg, V, 0);
        Observer.Observe('menu', Format(Pg.GetCurrentMenu()));
        ObserveSel('A', Pg, 0);
        if TryPartARecText(Pg, T) then
            Observer.Observe('A rec', T)
        else
            Observer.ObserveError('A rec error');
        Observer.Expect('runmodal', 'LookupOK');
        Observer.Expect('menu', '0');
        Observer.Expect('A count', '1');
        Observer.Expect('A filters', 'Vend: V1, Line No.: 10000');
        Observer.Expect('A rows', '10000;');
        Observer.Expect('A rec', 'V1/10000 filters []');
        Observer.Verify();
    end;

    [Test]
    [HandlerFunctions('DialogHandler')]
    procedure LT_C314_AfterRunModalOK_PartRowMoved()
    var
        V: Record "LT Y37 PC Vend";
        Pg: Page "LT Y37 PC Dialog";
    begin
        Seed(V);
        RunDialog(Pg, V, 1);
        ObserveSel('A', Pg, 0);
        Observer.Expect('runmodal', 'LookupOK');
        Observer.Expect('A count', '1');
        Observer.Expect('A filters', 'Vend: V1, Line No.: 20000');
        Observer.Expect('A rows', '20000;');
        Observer.Verify();
    end;

    [Test]
    [HandlerFunctions('DialogHandler')]
    procedure LT_C314_AfterRunModalOK_OtherPartShown()
    var
        V: Record "LT Y37 PC Vend";
        Pg: Page "LT Y37 PC Dialog";
    begin
        Seed(V);
        RunDialog(Pg, V, 2);
        Observer.Observe('menu', Format(Pg.GetCurrentMenu()));
        ObserveSel('B', Pg, 1);
        ObserveSel('A hidden', Pg, 0);
        Observer.Expect('runmodal', 'LookupOK');
        Observer.Expect('menu', '1');
        Observer.Expect('B count', '1');
        Observer.Expect('B filters', 'Vend: V1, Line No.: 40000');
        Observer.Expect('B rows', '40000;');
        Observer.Expect('A hidden count', '1');
        Observer.Expect('A hidden filters', 'Vend: V1, Line No.: 10000');
        Observer.Expect('A hidden rows', '10000;');
        Observer.Verify();
    end;

    [Test]
    [HandlerFunctions('DialogHandler')]
    procedure LT_C314_AfterRunModalCancel_PartSelection()
    var
        V: Record "LT Y37 PC Vend";
        Pg: Page "LT Y37 PC Dialog";
    begin
        Seed(V);
        RunDialog(Pg, V, 3);
        ObserveSel('A', Pg, 0);
        Observer.Expect('runmodal', 'LookupCancel');
        Observer.Expect('A count', '1');
        Observer.Expect('A filters', 'Vend: V1, Line No.: 10000');
        Observer.Expect('A rows', '10000;');
        Observer.Verify();
    end;

    [Test]
    [HandlerFunctions('DialogHandler')]
    procedure LT_C314_AfterRunModalOK_UpdateAndSave()
    var
        V: Record "LT Y37 PC Vend";
        Pg: Page "LT Y37 PC Dialog";
    begin
        Seed(V);
        RunDialog(Pg, V, 0);
        Step('host update false', TryHostUpdate(Pg, false));
        Step('host update true', TryHostUpdate(Pg, true));
        Step('host saverecord', TryHostSaveRecord(Pg));
        Step('part update', TryPartAUpdate(Pg));
        ObserveSel('A after', Pg, 0);
        V.Get('V1');
        Observer.Observe('stored name', V.Name);
        Observer.Expect('runmodal', 'LookupOK');
        Observer.Expect('host update false', 'Yes');
        Observer.Expect('host update true', 'Yes');
        Observer.Expect('host saverecord', 'Yes');
        Observer.Expect('part update', 'Yes');
        Observer.Expect('A after count', '1');
        Observer.Expect('A after filters', 'Vend: V1, Line No.: 10000');
        Observer.Expect('A after rows', '10000;');
        Observer.Expect('stored name', 'One');
        Observer.Verify();
    end;

    [Test]
    procedure LT_C314_NeverRan_PartSelection()
    var
        V: Record "LT Y37 PC Vend";
        Pg: Page "LT Y37 PC Dialog";
    begin
        Seed(V);
        Pg.SetRecord(V);
        ObserveSel('A', Pg, 0);
        ObserveSel('B', Pg, 1);
        Step('host update false', TryHostUpdate(Pg, false));
        Observer.Expect('A count', '0');
        Observer.Expect('A filters', 'Vend: '''', Line No.: 0');
        Observer.Expect('A rows', '');
        Observer.Expect('B count', '0');
        Observer.Expect('B filters', 'Vend: '''', Line No.: 0');
        Observer.Expect('B rows', '');
        Observer.Expect('host update false', 'Yes');
        Observer.Verify();
    end;

    [Test]
    procedure LT_C314_AfterRunClosed_PartSelection()
    var
        V: Record "LT Y37 PC Vend";
        Pg: Page "LT Y37 PC Dialog";
        P: TestPage "LT Y37 PC Dialog";
    begin
        Seed(V);
        P.Trap();
        Pg.SetRecord(V);
        Pg.Run();
        Observer.Observe('shown no', P."No.".Value());
        P.PartA.Last();
        Observer.Observe('shown part row', P.PartA."Line No.".Value());
        ObserveSel('A shown', Pg, 0);
        P.Close();
        ObserveSel('A closed', Pg, 0);
        Step('host update false closed', TryHostUpdate(Pg, false));
        Observer.Expect('shown no', 'V1');
        Observer.Expect('shown part row', '20000');
        Observer.Expect('A shown count', '0');
        Observer.Expect('A shown filters', 'Vend: '''', Line No.: 0');
        Observer.Expect('A shown rows', '');
        Observer.Expect('A closed count', '0');
        Observer.Expect('A closed filters', 'Vend: '''', Line No.: 0');
        Observer.Expect('A closed rows', '');
        Observer.Expect('host update false closed', 'Yes');
        Observer.Verify();
    end;

    // Observe-only native bootstrap. Finish() deliberately fails with complete OBSERVE pairs.
    // TryFunction cases measure the catch context. Direct cases separately record native test-boundary follow-up.
    var
        ClpParent: TestPage "PAG Trigger Close Parent";
        ClpLog: Codeunit "PAG Trigger Close Log";
        ClpPreserveTrace: Boolean;
        ClpBoundaryTrace: Text;
        ClpBoundaryCase: Text;
        ClpBoundaryQueries: Integer;
        ClpBoundaryFlag: Boolean;

    local procedure Initialize()
    var
        Cleanup: Codeunit ALTFixtureCleanup;
    begin
        // Snapshot continuation metadata before any reset, even if the codeunit flag was lost.
        ClpBoundaryTrace := ClpLog.ReadTrace();
        ClpBoundaryCase := ClpLog.ReadCase();
        ClpBoundaryQueries := ClpLog.QueryCount();
        ClpBoundaryFlag := ClpPreserveTrace;
        ClpPreserveTrace := false;
        Clear(ClpParent);
        ClpLog.Reset();
        Observer.Discard();
        Cleanup.Initialize();
    end;

    local procedure ClpFlag(Value: Boolean): Text
    begin
        if Value then
            exit('T');
        exit('F');
    end;

    [TryFunction]
    local procedure ClpTryOpen()
    begin
        ClpParent.OpenView();
    end;

    [TryFunction]
    local procedure ClpTryAction()
    begin
        ClpParent.ProbeAction.Invoke();
    end;

    [TryFunction]
    local procedure ClpTryParent(var Id: Integer)
    begin
        Id := ClpParent.ProbeId.AsInteger();
    end;

    [TryFunction]
    local procedure ClpTryPart(var Id: Integer)
    begin
        Id := ClpParent.PartBody.ProbeId.AsInteger();
    end;

    [TryFunction]
    local procedure ClpTryClose()
    begin
        ClpParent.Close();
    end;

    local procedure ClpCapture(UseAction: Boolean; RequestClose: Boolean; PermitClose: Boolean)
    var
        Opened: Boolean;
        ActionSucceeded: Boolean;
        ParentRead: Boolean;
        PartRead: Boolean;
        Closed: Boolean;
        ParentId: Integer;
        PartId: Integer;
        OpenCode: Text;
        OpenText: Text;
        ActionCode: Text;
        ActionText: Text;
        ParentCode: Text;
        ParentText: Text;
        PartCode: Text;
        PartText: Text;
        CloseCode: Text;
        CloseText: Text;
        OperationTrace: Text;
        OperationQueries: Integer;
    begin
        ClpLog.Configure(UseAction, RequestClose, PermitClose);
        ClearLastError();
        Opened := ClpTryOpen();
        if not Opened then begin
            OpenCode := GetLastErrorCode();
            OpenText := GetLastErrorText();
        end;
        if UseAction and Opened then begin
            ClearLastError();
            ActionSucceeded := ClpTryAction();
            if not ActionSucceeded then begin
                ActionCode := GetLastErrorCode();
                ActionText := GetLastErrorText();
            end;
        end;
        OperationTrace := ClpLog.ReadTrace();
        OperationQueries := ClpLog.QueryCount();
        ParentId := -777;
        PartId := -777;
        ClearLastError();
        ParentRead := ClpTryParent(ParentId);
        if not ParentRead then begin
            ParentCode := GetLastErrorCode();
            ParentText := GetLastErrorText();
        end;
        ClearLastError();
        PartRead := ClpTryPart(PartId);
        if not PartRead then begin
            PartCode := GetLastErrorCode();
            PartText := GetLastErrorText();
        end;
        ClearLastError();
        Closed := ClpTryClose();
        if not Closed then begin
            CloseCode := GetLastErrorCode();
            CloseText := GetLastErrorText();
        end;
        Observer.Observe('open.ok', ClpFlag(Opened));
        Observer.Observe('open.error.code', OpenCode);
        Observer.Observe('open.error.text', OpenText);
        Observer.Observe('action.requested', ClpFlag(UseAction));
        Observer.Observe('action.ok', ClpFlag(ActionSucceeded));
        Observer.Observe('action.error.code', ActionCode);
        Observer.Observe('action.error.text', ActionText);
        Observer.Observe('operation.trace', OperationTrace);
        Observer.Observe('operation.queries', Format(OperationQueries));
        Observer.Observe('follow.parent.ok', ClpFlag(ParentRead));
        Observer.Observe('follow.parent.id', Format(ParentId));
        Observer.Observe('follow.parent.error.code', ParentCode);
        Observer.Observe('follow.parent.error.text', ParentText);
        Observer.Observe('follow.part.ok', ClpFlag(PartRead));
        Observer.Observe('follow.part.id', Format(PartId));
        Observer.Observe('follow.part.error.code', PartCode);
        Observer.Observe('follow.part.error.text', PartText);
        Observer.Observe('follow.close.ok', ClpFlag(Closed));
        Observer.Observe('follow.close.error.code', CloseCode);
        Observer.Observe('follow.close.error.text', CloseText);
        Observer.Observe('follow.trace', ClpLog.ReadTrace());
        Observer.Observe('follow.queries', Format(ClpLog.QueryCount()));
        Observer.Observe('capture.end', 'COMPLETE');
        Observer.Verify();
    end;

    [Test]
    procedure CLP_AGCR_NoClose_PartAccess_Observe()
    begin
        Initialize();
        ClpExpect('CLP_AGCR_NoClose_PartAccess_Observe');
        ClpCapture(false, false, true);
    end;

    [Test]
    procedure CLP_AGCR_CloseAllowed_PartAccess_Observe()
    begin
        Initialize();
        ClpExpect('CLP_AGCR_CloseAllowed_PartAccess_Observe');
        ClpCapture(false, true, true);
    end;

    [Test]
    procedure CLP_AGCR_CloseVeto_PartAccess_Observe()
    begin
        Initialize();
        ClpExpect('CLP_AGCR_CloseVeto_PartAccess_Observe');
        ClpCapture(false, true, false);
    end;

    [Test]
    procedure CLP_Action_CloseAllowed_PartAccess_Observe()
    begin
        Initialize();
        ClpExpect('CLP_Action_CloseAllowed_PartAccess_Observe');
        ClpCapture(true, true, true);
    end;

    [Test]
    procedure CLP_Action_CloseVeto_PartAccess_Observe()
    begin
        Initialize();
        ClpExpect('CLP_Action_CloseVeto_PartAccess_Observe');
        ClpCapture(true, true, false);
    end;

    local procedure ClpDirect(UseAction: Boolean; RequestClose: Boolean; PermitClose: Boolean; Identity: Text)
    begin
        ClpLog.Configure(UseAction, RequestClose, PermitClose);
        ClpLog.SetCase(Identity);
        ClpPreserveTrace := true;
        ClpLog.Mark('TEST.BEFORE.OPEN');
        ClpParent.OpenView();
        ClpLog.Mark('TEST.AFTER.OPEN');
        if UseAction then begin
            ClpParent.ProbeAction.Invoke();
            ClpLog.Mark('TEST.AFTER.ACTION');
        end;
        Observer.Observe('direct.case', ClpLog.ReadCase());
        Observer.Observe('direct.returned', 'T');
        Observer.Observe('direct.trace', ClpLog.ReadTrace());
        Observer.Observe('direct.queries', Format(ClpLog.QueryCount()));
        Observer.Observe('capture.end', 'COMPLETE');
        Observer.Verify();
    end;

    local procedure ClpDirectBoundaryTrace(ExpectedIdentity: Text)
    begin
        // This includes any native test-runner cleanup after the previous test, not just the operation body.
        Observer.Observe('boundary.expected.case', ExpectedIdentity);
        Observer.Observe('boundary.actual.case', ClpBoundaryCase);
        Observer.Observe('boundary.paired', ClpFlag(ClpBoundaryCase = ExpectedIdentity));
        Observer.Observe('boundary.preserve.flag', ClpFlag(ClpBoundaryFlag));
        Observer.Observe('direct.post-test-boundary.trace', ClpBoundaryTrace);
        Observer.Observe('direct.post-test-boundary.queries', Format(ClpBoundaryQueries));
        Observer.Observe('capture.end', 'COMPLETE');
        Observer.Verify();
    end;

    [Test]
    procedure CLP_Direct_AGCR_NoClose_Observe()
    begin
        Initialize();
        ClpExpect('CLP_Direct_AGCR_NoClose_Observe');
        ClpDirect(false, false, true, 'AGCR_NoClose');
    end;

    [Test]
    procedure CLP_Direct_AGCR_NoClose_BoundaryTrace()
    begin
        Initialize();
        ClpExpect('CLP_Direct_AGCR_NoClose_BoundaryTrace');
        ClpDirectBoundaryTrace('AGCR_NoClose');
    end;

    [Test]
    procedure CLP_Direct_AGCR_CloseAllowed_Observe()
    begin
        Initialize();
        ClpExpect('CLP_Direct_AGCR_CloseAllowed_Observe');
        ClpDirect(false, true, true, 'AGCR_CloseAllowed');
    end;

    [Test]
    procedure CLP_Direct_AGCR_CloseAllowed_BoundaryTrace()
    begin
        Initialize();
        ClpExpect('CLP_Direct_AGCR_CloseAllowed_BoundaryTrace');
        ClpDirectBoundaryTrace('AGCR_CloseAllowed');
    end;

    [Test]
    procedure CLP_Direct_AGCR_CloseVeto_Observe()
    begin
        Initialize();
        ClpExpect('CLP_Direct_AGCR_CloseVeto_Observe');
        ClpDirect(false, true, false, 'AGCR_CloseVeto');
    end;

    [Test]
    procedure CLP_Direct_AGCR_CloseVeto_BoundaryTrace()
    begin
        Initialize();
        ClpExpect('CLP_Direct_AGCR_CloseVeto_BoundaryTrace');
        ClpDirectBoundaryTrace('AGCR_CloseVeto');
    end;

    [Test]
    procedure CLP_Direct_Action_CloseAllowed_Observe()
    begin
        Initialize();
        ClpExpect('CLP_Direct_Action_CloseAllowed_Observe');
        ClpDirect(true, true, true, 'Action_CloseAllowed');
    end;

    [Test]
    procedure CLP_Direct_Action_CloseAllowed_BoundaryTrace()
    begin
        Initialize();
        ClpExpect('CLP_Direct_Action_CloseAllowed_BoundaryTrace');
        ClpDirectBoundaryTrace('Action_CloseAllowed');
    end;

    [Test]
    procedure CLP_Direct_Action_CloseVeto_Observe()
    begin
        Initialize();
        ClpExpect('CLP_Direct_Action_CloseVeto_Observe');
        ClpDirect(true, true, false, 'Action_CloseVeto');
    end;

    [Test]
    procedure CLP_Direct_Action_CloseVeto_BoundaryTrace()
    begin
        Initialize();
        ClpExpect('CLP_Direct_Action_CloseVeto_BoundaryTrace');
        ClpDirectBoundaryTrace('Action_CloseVeto');
    end;

    // Exact native BC27.5 bootstrap pairs: run 41897699021, original JUnit retained.
    local procedure ClpExpect(ObservationCase: Text)
    begin
        case ObservationCase of
            'CLP_AGCR_NoClose_PartAccess_Observe':
                begin
                    Observer.Expect('open.ok', 'T');
                    Observer.Expect('open.error.code', '');
                    Observer.Expect('open.error.text', '');
                    Observer.Expect('action.requested', 'F');
                    Observer.Expect('action.ok', 'F');
                    Observer.Expect('action.error.code', '');
                    Observer.Expect('action.error.text', '');
                    Observer.Expect('operation.trace', 'PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.AGCR;NO.CLOSE;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;');
                    Observer.Expect('operation.queries', '0');
                    Observer.Expect('follow.parent.ok', 'T');
                    Observer.Expect('follow.parent.id', '1');
                    Observer.Expect('follow.parent.error.code', '');
                    Observer.Expect('follow.parent.error.text', '');
                    Observer.Expect('follow.part.ok', 'T');
                    Observer.Expect('follow.part.id', '1');
                    Observer.Expect('follow.part.error.code', '');
                    Observer.Expect('follow.part.error.text', '');
                    Observer.Expect('follow.close.ok', 'T');
                    Observer.Expect('follow.close.error.code', '');
                    Observer.Expect('follow.close.error.text', '');
                    Observer.Expect('follow.trace', 'PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.AGCR;NO.CLOSE;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;PARENT.QUERY:OK;PART.CLOSE;PARENT.CLOSE;');
                    Observer.Expect('follow.queries', '1');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_AGCR_CloseAllowed_PartAccess_Observe':
                begin
                    Observer.Expect('open.ok', 'T');
                    Observer.Expect('open.error.code', '');
                    Observer.Expect('open.error.text', '');
                    Observer.Expect('action.requested', 'F');
                    Observer.Expect('action.ok', 'F');
                    Observer.Expect('action.error.code', '');
                    Observer.Expect('action.error.text', '');
                    Observer.Expect('operation.trace', 'PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.AGCR;BEFORE.CLOSE;PARENT.QUERY:OK;PART.CLOSE;PARENT.CLOSE;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:1042:1;AFTER.PART:1042:1;');
                    Observer.Expect('operation.queries', '1');
                    Observer.Expect('follow.parent.ok', 'F');
                    Observer.Expect('follow.parent.id', '-777');
                    Observer.Expect('follow.parent.error.code', 'TestPageNotOpened');
                    Observer.Expect('follow.parent.error.text', 'The TestPage is not open.');
                    Observer.Expect('follow.part.ok', 'F');
                    Observer.Expect('follow.part.id', '-777');
                    Observer.Expect('follow.part.error.code', 'TestPageNotOpened');
                    Observer.Expect('follow.part.error.text', 'The TestPage is not open.');
                    Observer.Expect('follow.close.ok', 'F');
                    Observer.Expect('follow.close.error.code', 'TestPageNotOpened');
                    Observer.Expect('follow.close.error.text', 'The TestPage is not open.');
                    Observer.Expect('follow.trace', 'PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.AGCR;BEFORE.CLOSE;PARENT.QUERY:OK;PART.CLOSE;PARENT.CLOSE;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:1042:1;AFTER.PART:1042:1;');
                    Observer.Expect('follow.queries', '1');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_AGCR_CloseVeto_PartAccess_Observe':
                begin
                    Observer.Expect('open.ok', 'T');
                    Observer.Expect('open.error.code', '');
                    Observer.Expect('open.error.text', '');
                    Observer.Expect('action.requested', 'F');
                    Observer.Expect('action.ok', 'F');
                    Observer.Expect('action.error.code', '');
                    Observer.Expect('action.error.text', '');
                    Observer.Expect('operation.trace', 'PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.AGCR;BEFORE.CLOSE;PARENT.QUERY:OK;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;PARENT.QUERY:OK;');
                    Observer.Expect('operation.queries', '2');
                    Observer.Expect('follow.parent.ok', 'T');
                    Observer.Expect('follow.parent.id', '0');
                    Observer.Expect('follow.parent.error.code', '');
                    Observer.Expect('follow.parent.error.text', '');
                    Observer.Expect('follow.part.ok', 'T');
                    Observer.Expect('follow.part.id', '1');
                    Observer.Expect('follow.part.error.code', '');
                    Observer.Expect('follow.part.error.text', '');
                    Observer.Expect('follow.close.ok', 'T');
                    Observer.Expect('follow.close.error.code', '');
                    Observer.Expect('follow.close.error.text', '');
                    Observer.Expect('follow.trace', 'PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.AGCR;BEFORE.CLOSE;PARENT.QUERY:OK;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;PARENT.QUERY:OK;PARENT.QUERY:OK;');
                    Observer.Expect('follow.queries', '3');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Action_CloseAllowed_PartAccess_Observe':
                begin
                    Observer.Expect('open.ok', 'T');
                    Observer.Expect('open.error.code', '');
                    Observer.Expect('open.error.text', '');
                    Observer.Expect('action.requested', 'T');
                    Observer.Expect('action.ok', 'T');
                    Observer.Expect('action.error.code', '');
                    Observer.Expect('action.error.text', '');
                    Observer.Expect('operation.trace', 'PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.ACTION;BEFORE.CLOSE;PARENT.QUERY:OK;PART.CLOSE;PARENT.CLOSE;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:1042:1;AFTER.PART:1042:1;');
                    Observer.Expect('operation.queries', '1');
                    Observer.Expect('follow.parent.ok', 'F');
                    Observer.Expect('follow.parent.id', '-777');
                    Observer.Expect('follow.parent.error.code', 'TestPageNotOpened');
                    Observer.Expect('follow.parent.error.text', 'The TestPage is not open.');
                    Observer.Expect('follow.part.ok', 'F');
                    Observer.Expect('follow.part.id', '-777');
                    Observer.Expect('follow.part.error.code', 'TestPageNotOpened');
                    Observer.Expect('follow.part.error.text', 'The TestPage is not open.');
                    Observer.Expect('follow.close.ok', 'F');
                    Observer.Expect('follow.close.error.code', 'TestPageNotOpened');
                    Observer.Expect('follow.close.error.text', 'The TestPage is not open.');
                    Observer.Expect('follow.trace', 'PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.ACTION;BEFORE.CLOSE;PARENT.QUERY:OK;PART.CLOSE;PARENT.CLOSE;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:1042:1;AFTER.PART:1042:1;');
                    Observer.Expect('follow.queries', '1');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Action_CloseVeto_PartAccess_Observe':
                begin
                    Observer.Expect('open.ok', 'T');
                    Observer.Expect('open.error.code', '');
                    Observer.Expect('open.error.text', '');
                    Observer.Expect('action.requested', 'T');
                    Observer.Expect('action.ok', 'T');
                    Observer.Expect('action.error.code', '');
                    Observer.Expect('action.error.text', '');
                    Observer.Expect('operation.trace', 'PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.ACTION;BEFORE.CLOSE;PARENT.QUERY:OK;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;PARENT.QUERY:OK;');
                    Observer.Expect('operation.queries', '2');
                    Observer.Expect('follow.parent.ok', 'T');
                    Observer.Expect('follow.parent.id', '1');
                    Observer.Expect('follow.parent.error.code', '');
                    Observer.Expect('follow.parent.error.text', '');
                    Observer.Expect('follow.part.ok', 'T');
                    Observer.Expect('follow.part.id', '1');
                    Observer.Expect('follow.part.error.code', '');
                    Observer.Expect('follow.part.error.text', '');
                    Observer.Expect('follow.close.ok', 'T');
                    Observer.Expect('follow.close.error.code', '');
                    Observer.Expect('follow.close.error.text', '');
                    Observer.Expect('follow.trace', 'PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.ACTION;BEFORE.CLOSE;PARENT.QUERY:OK;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;PARENT.QUERY:OK;PARENT.QUERY:OK;');
                    Observer.Expect('follow.queries', '3');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Direct_AGCR_NoClose_Observe':
                begin
                    Observer.Expect('direct.case', 'AGCR_NoClose');
                    Observer.Expect('direct.returned', 'T');
                    Observer.Expect('direct.trace', 'TEST.BEFORE.OPEN;PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.AGCR;NO.CLOSE;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;TEST.AFTER.OPEN;');
                    Observer.Expect('direct.queries', '0');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Direct_AGCR_NoClose_BoundaryTrace':
                begin
                    Observer.Expect('boundary.expected.case', 'AGCR_NoClose');
                    Observer.Expect('boundary.actual.case', 'AGCR_NoClose');
                    Observer.Expect('boundary.paired', 'T');
                    Observer.Expect('boundary.preserve.flag', 'T');
                    Observer.Expect('direct.post-test-boundary.trace', 'TEST.BEFORE.OPEN;PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.AGCR;NO.CLOSE;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;TEST.AFTER.OPEN;');
                    Observer.Expect('direct.post-test-boundary.queries', '0');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Direct_AGCR_CloseAllowed_Observe':
                begin
                    Observer.Expect('direct.case', 'AGCR_CloseAllowed');
                    Observer.Expect('direct.returned', 'T');
                    Observer.Expect('direct.trace', 'TEST.BEFORE.OPEN;PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.AGCR;BEFORE.CLOSE;PARENT.QUERY:OK;PART.CLOSE;PARENT.CLOSE;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:1042:1;AFTER.PART:1042:1;TEST.AFTER.OPEN;');
                    Observer.Expect('direct.queries', '1');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Direct_AGCR_CloseAllowed_BoundaryTrace':
                begin
                    Observer.Expect('boundary.expected.case', 'AGCR_CloseAllowed');
                    Observer.Expect('boundary.actual.case', 'AGCR_CloseAllowed');
                    Observer.Expect('boundary.paired', 'T');
                    Observer.Expect('boundary.preserve.flag', 'T');
                    Observer.Expect('direct.post-test-boundary.trace', 'TEST.BEFORE.OPEN;PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.AGCR;BEFORE.CLOSE;PARENT.QUERY:OK;PART.CLOSE;PARENT.CLOSE;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:1042:1;AFTER.PART:1042:1;TEST.AFTER.OPEN;');
                    Observer.Expect('direct.post-test-boundary.queries', '1');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Direct_AGCR_CloseVeto_Observe':
                begin
                    Observer.Expect('direct.case', 'AGCR_CloseVeto');
                    Observer.Expect('direct.returned', 'T');
                    Observer.Expect('direct.trace', 'TEST.BEFORE.OPEN;PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.AGCR;BEFORE.CLOSE;PARENT.QUERY:OK;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;PARENT.QUERY:OK;TEST.AFTER.OPEN;');
                    Observer.Expect('direct.queries', '2');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Direct_AGCR_CloseVeto_BoundaryTrace':
                begin
                    Observer.Expect('boundary.expected.case', 'AGCR_CloseVeto');
                    Observer.Expect('boundary.actual.case', 'AGCR_CloseVeto');
                    Observer.Expect('boundary.paired', 'T');
                    Observer.Expect('boundary.preserve.flag', 'T');
                    Observer.Expect('direct.post-test-boundary.trace', 'TEST.BEFORE.OPEN;PART.INIT;PARENT.OPEN;PART.OPEN;PARENT.AGCR;BEFORE.CLOSE;PARENT.QUERY:OK;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;PARENT.QUERY:OK;TEST.AFTER.OPEN;');
                    Observer.Expect('direct.post-test-boundary.queries', '2');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Direct_Action_CloseAllowed_Observe':
                begin
                    Observer.Expect('direct.case', 'Action_CloseAllowed');
                    Observer.Expect('direct.returned', 'T');
                    Observer.Expect('direct.trace', 'TEST.BEFORE.OPEN;PART.INIT;PARENT.OPEN;PART.OPEN;TEST.AFTER.OPEN;PARENT.ACTION;BEFORE.CLOSE;PARENT.QUERY:OK;PART.CLOSE;PARENT.CLOSE;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:1042:1;AFTER.PART:1042:1;TEST.AFTER.ACTION;');
                    Observer.Expect('direct.queries', '1');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Direct_Action_CloseAllowed_BoundaryTrace':
                begin
                    Observer.Expect('boundary.expected.case', 'Action_CloseAllowed');
                    Observer.Expect('boundary.actual.case', 'Action_CloseAllowed');
                    Observer.Expect('boundary.paired', 'T');
                    Observer.Expect('boundary.preserve.flag', 'T');
                    Observer.Expect('direct.post-test-boundary.trace', 'TEST.BEFORE.OPEN;PART.INIT;PARENT.OPEN;PART.OPEN;TEST.AFTER.OPEN;PARENT.ACTION;BEFORE.CLOSE;PARENT.QUERY:OK;PART.CLOSE;PARENT.CLOSE;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:1042:1;AFTER.PART:1042:1;TEST.AFTER.ACTION;');
                    Observer.Expect('direct.post-test-boundary.queries', '1');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Direct_Action_CloseVeto_Observe':
                begin
                    Observer.Expect('direct.case', 'Action_CloseVeto');
                    Observer.Expect('direct.returned', 'T');
                    Observer.Expect('direct.trace', 'TEST.BEFORE.OPEN;PART.INIT;PARENT.OPEN;PART.OPEN;TEST.AFTER.OPEN;PARENT.ACTION;BEFORE.CLOSE;PARENT.QUERY:OK;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;PARENT.QUERY:OK;TEST.AFTER.ACTION;');
                    Observer.Expect('direct.queries', '2');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Direct_Action_CloseVeto_BoundaryTrace':
                begin
                    Observer.Expect('boundary.expected.case', 'Action_CloseVeto');
                    Observer.Expect('boundary.actual.case', 'Action_CloseVeto');
                    Observer.Expect('boundary.paired', 'T');
                    Observer.Expect('boundary.preserve.flag', 'T');
                    Observer.Expect('direct.post-test-boundary.trace', 'TEST.BEFORE.OPEN;PART.INIT;PARENT.OPEN;PART.OPEN;TEST.AFTER.OPEN;PARENT.ACTION;BEFORE.CLOSE;PARENT.QUERY:OK;AFTER.CLOSE;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;PARENT.QUERY:OK;TEST.AFTER.ACTION;');
                    Observer.Expect('direct.post-test-boundary.queries', '2');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            else
                Error('Unknown close/part observation case: %1', ObservationCase);
        end;
    end;

    // Exact complete observations at writer40348e72 matched on native BC27.5/28.5/29.0.
    // Action preprocessing remains a separate observable boundary, not a pre-invoke Rec proof.
    local procedure ClpDetailedOpen(RequestClose: Boolean; PermitClose: Boolean; Identity: Text)
    var
        OperationTrace: Text;
        OperationQueries: Integer;
        OperationAgcr: Integer;
        Cleaned: Boolean;
        BeforeRead: Boolean;
        BeforeId: Integer;
        BeforeCode: Text;
        ActionOk: Boolean;
        ActionCode: Text;
        AfterRead: Boolean;
        AfterId: Integer;
        AfterCode: Text;
        FollowTrace: Text;
        FollowQueries: Integer;
        FollowAgcr: Integer;
    begin
        ClpLog.Configure(false, RequestClose, PermitClose);
        ClpLog.EnableDetails();
        ClpLog.Mark('DETAIL.BEFORE.OPEN');
        ClpParent.OpenView();
        ClpLog.Mark('DETAIL.OPERATION.END');
        OperationTrace := ClpLog.ReadTrace();
        OperationQueries := ClpLog.QueryCount();
        OperationAgcr := ClpLog.AgcrCount();
        // Freeze the original operation first. Action processing is a separate contrast.
        BeforeId := -777;
        ClearLastError();
        BeforeRead := ClpTryParent(BeforeId);
        if not BeforeRead then
            BeforeCode := GetLastErrorCode();
        ClearLastError();
        ActionOk := ClpTryDetailReadAction();
        if not ActionOk then
            ActionCode := GetLastErrorCode();
        AfterId := -777;
        ClearLastError();
        AfterRead := ClpTryParent(AfterId);
        if not AfterRead then
            AfterCode := GetLastErrorCode();
        FollowTrace := CopyStr(ClpLog.ReadTrace(), StrLen(OperationTrace) + 1);
        FollowQueries := ClpLog.QueryCount();
        FollowAgcr := ClpLog.AgcrCount();
        Observer.Observe('detail.case', Identity);
        Observer.Observe('operation.trace', OperationTrace);
        Observer.Observe('operation.queries', Format(OperationQueries));
        Observer.Observe('operation.agcr', Format(OperationAgcr));
        Observer.Observe('follow.before.ok', ClpFlag(BeforeRead));
        Observer.Observe('follow.before.id', Format(BeforeId));
        Observer.Observe('follow.before.error.code', BeforeCode);
        Observer.Observe('follow.action.ok', ClpFlag(ActionOk));
        Observer.Observe('follow.action.error.code', ActionCode);
        Observer.Observe('follow.trace', FollowTrace);
        Observer.Observe('follow.queries', Format(FollowQueries));
        Observer.Observe('follow.agcr', Format(FollowAgcr));
        Observer.Observe('follow.after.ok', ClpFlag(AfterRead));
        Observer.Observe('follow.after.id', Format(AfterId));
        Observer.Observe('follow.after.error.code', AfterCode);
        ClpLog.Mark('DETAIL.CLEANUP.BEGIN');
        Cleaned := ClpTryClose();
        Observer.Observe('cleanup.ok', ClpFlag(Cleaned));
        Observer.Observe('cleanup.queries', Format(ClpLog.QueryCount()));
        Observer.Observe('capture.end', 'COMPLETE');
        ClpDetailedExpect(Identity);
        Observer.Verify();
    end;

    [Test]
    procedure CLP_Detail_AGCR_NoClose_Observe()
    begin
        Initialize();
        ClpDetailedOpen(false, true, 'CLP_Detail_AGCR_NoClose_Observe');
    end;


    [Test]
    procedure CLP_Detail_AGCR_Allowed_Observe()
    begin
        Initialize();
        ClpDetailedOpen(true, true, 'CLP_Detail_AGCR_Allowed_Observe');
    end;


    [Test]
    procedure CLP_Detail_AGCR_Veto_Observe()
    begin
        Initialize();
        ClpDetailedOpen(true, false, 'CLP_Detail_AGCR_Veto_Observe');
    end;


    [TryFunction]
    local procedure ClpTryDetailReadAction()
    begin
        ClpParent.DetailReadRecord.Invoke();
    end;

    local procedure ClpDetailedExpect(Identity: Text)
    begin
        case Identity of
            'CLP_Detail_AGCR_NoClose_Observe':
                begin
                    Observer.Expect('detail.case', 'CLP_Detail_AGCR_NoClose_Observe');
                    Observer.Expect('operation.trace', 'DETAIL.BEFORE.OPEN;PART.INIT;D:OPEN.before:id=0:agcr=0:q=0:probed=No;PARENT.OPEN;D:OPEN.after:id=1:agcr=0:q=0:probed=No;PART.OPEN;D:AGCR.entry:id=1:agcr=1:q=0:probed=No;PARENT.AGCR;NO.CLOSE;D:PART.before:id=1:agcr=1:q=0:probed=Yes;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;D:PART.after:42:1:id=1:agcr=1:q=0:probed=Yes;DETAIL.OPERATION.END;');
                    Observer.Expect('operation.queries', '0');
                    Observer.Expect('operation.agcr', '1');
                    Observer.Expect('follow.before.ok', 'T');
                    Observer.Expect('follow.before.id', '1');
                    Observer.Expect('follow.before.error.code', '');
                    Observer.Expect('follow.action.ok', 'T');
                    Observer.Expect('follow.action.error.code', '');
                    Observer.Expect('follow.trace', 'D:FOLLOW.ACTION:id=1:agcr=1:q=0:probed=Yes;D:AGCR.entry:id=1:agcr=2:q=0:probed=Yes;');
                    Observer.Expect('follow.queries', '0');
                    Observer.Expect('follow.agcr', '2');
                    Observer.Expect('follow.after.ok', 'T');
                    Observer.Expect('follow.after.id', '1');
                    Observer.Expect('follow.after.error.code', '');
                    Observer.Expect('cleanup.ok', 'T');
                    Observer.Expect('cleanup.queries', '1');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Detail_AGCR_Allowed_Observe':
                begin
                    Observer.Expect('detail.case', 'CLP_Detail_AGCR_Allowed_Observe');
                    Observer.Expect('operation.trace', 'DETAIL.BEFORE.OPEN;PART.INIT;D:OPEN.before:id=0:agcr=0:q=0:probed=No;PARENT.OPEN;D:OPEN.after:id=1:agcr=0:q=0:probed=No;PART.OPEN;D:AGCR.entry:id=1:agcr=1:q=0:probed=No;PARENT.AGCR;D:CALL.CLOSE.before:id=1:agcr=1:q=0:probed=Yes;BEFORE.CLOSE;PARENT.QUERY:OK;D:QUERY.entry:OK:id=1:agcr=1:q=1:probed=Yes;D:QUERY.return:Yes:id=1:agcr=1:q=1:probed=Yes;PART.CLOSE;D:CLOSE.entry:id=1:agcr=1:q=1:probed=Yes;PARENT.CLOSE;AFTER.CLOSE;D:CALL.CLOSE.after:id=1:agcr=1:q=1:probed=Yes;D:PART.before:id=1:agcr=1:q=1:probed=Yes;BEFORE.PART;PART.TOUCH:1042:1;AFTER.PART:1042:1;D:PART.after:1042:1:id=1:agcr=1:q=1:probed=Yes;DETAIL.OPERATION.END;');
                    Observer.Expect('operation.queries', '1');
                    Observer.Expect('operation.agcr', '1');
                    Observer.Expect('follow.before.ok', 'F');
                    Observer.Expect('follow.before.id', '-777');
                    Observer.Expect('follow.before.error.code', 'TestPageNotOpened');
                    Observer.Expect('follow.action.ok', 'F');
                    Observer.Expect('follow.action.error.code', 'TestPageNotOpened');
                    Observer.Expect('follow.trace', '');
                    Observer.Expect('follow.queries', '1');
                    Observer.Expect('follow.agcr', '1');
                    Observer.Expect('follow.after.ok', 'F');
                    Observer.Expect('follow.after.id', '-777');
                    Observer.Expect('follow.after.error.code', 'TestPageNotOpened');
                    Observer.Expect('cleanup.ok', 'F');
                    Observer.Expect('cleanup.queries', '1');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'CLP_Detail_AGCR_Veto_Observe':
                begin
                    Observer.Expect('detail.case', 'CLP_Detail_AGCR_Veto_Observe');
                    Observer.Expect('operation.trace', 'DETAIL.BEFORE.OPEN;PART.INIT;D:OPEN.before:id=0:agcr=0:q=0:probed=No;PARENT.OPEN;D:OPEN.after:id=1:agcr=0:q=0:probed=No;PART.OPEN;D:AGCR.entry:id=1:agcr=1:q=0:probed=No;PARENT.AGCR;D:CALL.CLOSE.before:id=1:agcr=1:q=0:probed=Yes;BEFORE.CLOSE;PARENT.QUERY:OK;D:QUERY.entry:OK:id=1:agcr=1:q=1:probed=Yes;D:QUERY.return:No:id=1:agcr=1:q=1:probed=Yes;AFTER.CLOSE;D:CALL.CLOSE.after:id=1:agcr=1:q=1:probed=Yes;D:PART.before:id=1:agcr=1:q=1:probed=Yes;BEFORE.PART;PART.TOUCH:42:1;AFTER.PART:42:1;D:PART.after:42:1:id=1:agcr=1:q=1:probed=Yes;PARENT.QUERY:OK;D:QUERY.entry:OK:id=1:agcr=1:q=2:probed=Yes;D:QUERY.return:No:id=1:agcr=1:q=2:probed=Yes;DETAIL.OPERATION.END;');
                    Observer.Expect('operation.queries', '2');
                    Observer.Expect('operation.agcr', '1');
                    Observer.Expect('follow.before.ok', 'T');
                    Observer.Expect('follow.before.id', '0');
                    Observer.Expect('follow.before.error.code', '');
                    Observer.Expect('follow.action.ok', 'T');
                    Observer.Expect('follow.action.error.code', '');
                    Observer.Expect('follow.trace', 'D:FOLLOW.ACTION:id=1:agcr=1:q=2:probed=Yes;D:AGCR.entry:id=1:agcr=2:q=2:probed=Yes;');
                    Observer.Expect('follow.queries', '2');
                    Observer.Expect('follow.agcr', '2');
                    Observer.Expect('follow.after.ok', 'T');
                    Observer.Expect('follow.after.id', '1');
                    Observer.Expect('follow.after.error.code', '');
                    Observer.Expect('cleanup.ok', 'T');
                    Observer.Expect('cleanup.queries', '3');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            else
                Error('Unknown detailed close observation: %1', Identity);
        end;
    end;

    var
        MRCurrentPage: Page "PAG Modal Writes Dialog";

    // Separate direct and TryFunction call contexts; no TryFunction rollback/durability claim.
    [ModalPageHandler]
    procedure MRDialogHandler(var P: TestPage "PAG Modal Writes Dialog")
    var L: Codeunit "PAG Modal Writes Log";
    begin
        if L.Mode() = 3 then Error('modal lifecycle handler failure');
        if L.Mode() in [4, 5] then MROwnHandler();
        if L.Mode() = 2 then begin
            P.Probe.Invoke();
            // A distinct snapshot after the UI action and its refresh pipeline return.
            L.AfterInvoke(MRCurrentPage.Snapshot(L.Side()), L.ReadTrace());
        end;
        if L.Mode() = 1 then P.Cancel().Invoke() else P.OK().Invoke();
    end;

    [TryFunction]
    local procedure MRTryOperate(var Pg: Page "PAG Modal Writes Dialog"; Side: Integer; Op: Integer)
    begin Pg.Operate(Side, Op); end;

    local procedure MRRunWithoutFinish(Identity: Text; RowId: Integer; Mode: Integer; Side: Integer; Op: Integer; CatchOperation: Boolean)
    var H: Record "PAG Modal Writes Host"; R: Record "PAG Modal Writes Line";
        L: Codeunit "PAG Modal Writes Log";
        ResultAction: Action; OperationOk: Boolean; OperationCode: Text;
    begin
        Clear(MRCurrentPage); L.Configure(Mode, Side, Op, RowId);
        H.Id := RowId; H.Value := 'host-seed'; H.Insert(false);
        R.Id := RowId; R.Value := 'part-seed'; R.Insert(false);
        MRCurrentPage.SetRecord(H); MRCurrentPage.LookupMode := true;
        ResultAction := MRCurrentPage.RunModal();
        Observer.Observe('case', Identity);
        Observer.Observe('returned', Format(ResultAction));
        if Mode = 2 then begin
            Observer.Observe('before', L.BeforeText());
            Observer.Observe('after', L.AfterText());
            Observer.Observe('trace.in-action', L.OperationTrace());
            Observer.Observe('after.invoke', L.AfterInvokeText());
            Observer.Observe('trace.after-invoke', L.AfterInvokeTraceText());
        end else begin
            // The decisive dirty assignment occurs AFTER modal close, excluding save-on-close.
            L.ResetTrace(); MRCurrentPage.Dirty(Side);
            Observer.Observe('before', MRCurrentPage.Snapshot(Side));
            L.Phase('before-post-operation');
            if CatchOperation then begin
                ClearLastError(); OperationOk := MRTryOperate(MRCurrentPage, Side, Op);
                if not OperationOk then OperationCode := GetLastErrorCode();
                Observer.Observe('try.ok', Format(OperationOk));
                Observer.Observe('try.error.code', OperationCode);
            end else MRCurrentPage.Operate(Side, Op);
            L.Phase('after-post-operation');
            Observer.Observe('after', MRCurrentPage.Snapshot(Side));
            Observer.Observe('trace', L.ReadTrace());
        end;
        Observer.Observe('capture.end', 'COMPLETE');
    end;

    local procedure MRRun(Identity: Text; RowId: Integer; Mode: Integer; Side: Integer; Op: Integer; CatchOperation: Boolean)
    begin
        MRRunWithoutFinish(Identity, RowId, Mode, Side, Op, CatchOperation);
        MRExpect(Identity);
        Observer.Verify();
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_OK_Host_UpdateFalse_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_OK_Host_UpdateFalse_Direct_Observe', 1, 0, 0, 0, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_OK_Host_UpdateTrue_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_OK_Host_UpdateTrue_Direct_Observe', 2, 0, 0, 1, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_OK_Host_SaveRecord_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_OK_Host_SaveRecord_Direct_Observe', 3, 0, 0, 2, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_OK_Part_UpdateFalse_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_OK_Part_UpdateFalse_Direct_Observe', 4, 0, 1, 0, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_OK_Part_UpdateTrue_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_OK_Part_UpdateTrue_Direct_Observe', 5, 0, 1, 1, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_OK_Part_SaveRecord_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_OK_Part_SaveRecord_Direct_Observe', 6, 0, 1, 2, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Cancel_Host_UpdateFalse_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_Cancel_Host_UpdateFalse_Direct_Observe', 7, 1, 0, 0, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Cancel_Host_UpdateTrue_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_Cancel_Host_UpdateTrue_Direct_Observe', 8, 1, 0, 1, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Cancel_Host_SaveRecord_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_Cancel_Host_SaveRecord_Direct_Observe', 9, 1, 0, 2, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Cancel_Part_UpdateFalse_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_Cancel_Part_UpdateFalse_Direct_Observe', 10, 1, 1, 0, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Cancel_Part_UpdateTrue_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_Cancel_Part_UpdateTrue_Direct_Observe', 11, 1, 1, 1, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Cancel_Part_SaveRecord_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_Cancel_Part_SaveRecord_Direct_Observe', 12, 1, 1, 2, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_OK_Host_UpdateFalse_Try_Observe()
    begin
        Initialize();
        MRRun('MR_OK_Host_UpdateFalse_Try_Observe', 13, 0, 0, 0, true);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_OK_Host_UpdateTrue_Try_Observe()
    begin
        Initialize();
        asserterror MRRunWithoutFinish('MR_OK_Host_UpdateTrue_Try_Observe', 14, 0, 0, 1, true);
        Observer.ObserveError('fatal');
        MRFatalFinish('MR_OK_Host_UpdateTrue_Try_Observe');
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_OK_Host_SaveRecord_Try_Observe()
    begin
        Initialize();
        asserterror MRRunWithoutFinish('MR_OK_Host_SaveRecord_Try_Observe', 15, 0, 0, 2, true);
        Observer.ObserveError('fatal');
        MRFatalFinish('MR_OK_Host_SaveRecord_Try_Observe');
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_OK_Part_UpdateFalse_Try_Observe()
    begin
        Initialize();
        MRRun('MR_OK_Part_UpdateFalse_Try_Observe', 16, 0, 1, 0, true);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_OK_Part_UpdateTrue_Try_Observe()
    begin
        Initialize();
        asserterror MRRunWithoutFinish('MR_OK_Part_UpdateTrue_Try_Observe', 17, 0, 1, 1, true);
        Observer.ObserveError('fatal');
        MRFatalFinish('MR_OK_Part_UpdateTrue_Try_Observe');
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_OK_Part_SaveRecord_Try_Observe()
    begin
        Initialize();
        asserterror MRRunWithoutFinish('MR_OK_Part_SaveRecord_Try_Observe', 18, 0, 1, 2, true);
        Observer.ObserveError('fatal');
        MRFatalFinish('MR_OK_Part_SaveRecord_Try_Observe');
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Cancel_Host_UpdateFalse_Try_Observe()
    begin
        Initialize();
        MRRun('MR_Cancel_Host_UpdateFalse_Try_Observe', 19, 1, 0, 0, true);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Cancel_Host_UpdateTrue_Try_Observe()
    begin
        Initialize();
        asserterror MRRunWithoutFinish('MR_Cancel_Host_UpdateTrue_Try_Observe', 20, 1, 0, 1, true);
        Observer.ObserveError('fatal');
        MRFatalFinish('MR_Cancel_Host_UpdateTrue_Try_Observe');
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Cancel_Host_SaveRecord_Try_Observe()
    begin
        Initialize();
        asserterror MRRunWithoutFinish('MR_Cancel_Host_SaveRecord_Try_Observe', 21, 1, 0, 2, true);
        Observer.ObserveError('fatal');
        MRFatalFinish('MR_Cancel_Host_SaveRecord_Try_Observe');
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Cancel_Part_UpdateFalse_Try_Observe()
    begin
        Initialize();
        MRRun('MR_Cancel_Part_UpdateFalse_Try_Observe', 22, 1, 1, 0, true);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Cancel_Part_UpdateTrue_Try_Observe()
    begin
        Initialize();
        asserterror MRRunWithoutFinish('MR_Cancel_Part_UpdateTrue_Try_Observe', 23, 1, 1, 1, true);
        Observer.ObserveError('fatal');
        MRFatalFinish('MR_Cancel_Part_UpdateTrue_Try_Observe');
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Cancel_Part_SaveRecord_Try_Observe()
    begin
        Initialize();
        asserterror MRRunWithoutFinish('MR_Cancel_Part_SaveRecord_Try_Observe', 24, 1, 1, 2, true);
        Observer.ObserveError('fatal');
        MRFatalFinish('MR_Cancel_Part_SaveRecord_Try_Observe');
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Open_Host_UpdateFalse_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_Open_Host_UpdateFalse_Direct_Observe', 25, 2, 0, 0, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Open_Host_UpdateTrue_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_Open_Host_UpdateTrue_Direct_Observe', 26, 2, 0, 1, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Open_Host_SaveRecord_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_Open_Host_SaveRecord_Direct_Observe', 27, 2, 0, 2, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Open_Part_UpdateFalse_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_Open_Part_UpdateFalse_Direct_Observe', 28, 2, 1, 0, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Open_Part_UpdateTrue_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_Open_Part_UpdateTrue_Direct_Observe', 29, 2, 1, 1, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MR_Open_Part_SaveRecord_Direct_Observe()
    begin
        Initialize();
        MRRun('MR_Open_Part_SaveRecord_Direct_Observe', 30, 2, 1, 2, false);
    end;

    // Lifecycle observations are about values/access, not heap release or OnInit identity.
    local procedure MRLSeed(RowId: Integer)
    var H: Record "PAG Modal Writes Host"; R: Record "PAG Modal Writes Line";
    begin
        H.Id := RowId; H.Value := 'host-seed'; H.Insert(false);
        R.Id := RowId; R.Value := 'part-seed'; R.Insert(false);
    end;

    local procedure MRLSet(RowId: Integer; Mode: Integer)
    var H: Record "PAG Modal Writes Host"; L: Codeunit "PAG Modal Writes Log";
    begin
        L.Configure(Mode, 1, 0, RowId);
        H.Get(RowId); MRCurrentPage.SetRecord(H);
    end;

    local procedure MRLDatabase(RowId: Integer): Text
    var H: Record "PAG Modal Writes Host"; R: Record "PAG Modal Writes Line";
    begin
        H.Get(RowId); R.Get(RowId);
        exit(Format(RowId) + ':H=' + H.Value + ';P=' + R.Value);
    end;

    [TryFunction]
    local procedure MRLTryPartSnapshot(var Value: Text)
    begin Value := MRCurrentPage.Snapshot(1); end;

    local procedure MRLSnapshot(LabelText: Text)
    var Value: Text; Ok: Boolean; ErrorCode: Text; L: Codeunit "PAG Modal Writes Log";
    begin
        Observer.Observe(LabelText + '.trace.before', L.ReadTrace());
        ClearLastError(); Ok := MRLTryPartSnapshot(Value);
        if not Ok then ErrorCode := GetLastErrorCode();
        Observer.Observe(LabelText + '.ok', Format(Ok));
        Observer.Observe(LabelText + '.error.code', ErrorCode);
        Observer.Observe(LabelText + '.value', Value);
        Observer.Observe(LabelText + '.trace.after', L.ReadTrace());
    end;

    [TryFunction]
    local procedure MRLTryRun(var Answer: Action)
    begin Answer := MRCurrentPage.RunModal(); end;

    local procedure MRLRunError()
    var Answer: Action; Ok: Boolean; ErrorCode: Text;
    begin
        ClearLastError(); Ok := MRLTryRun(Answer);
        if not Ok then ErrorCode := GetLastErrorCode();
        Observer.Observe('run.ok', Format(Ok));
        Observer.Observe('run.error.code', ErrorCode);
        Observer.Observe('run.answer', Format(Answer));
    end;

    local procedure MRLFinish(Identity: Text)
    begin
        Observer.Observe('case', Identity);
        Observer.Observe('capture.end', 'COMPLETE');
        MRExpect(Identity);
        Observer.Verify();
    end;

    [Test]
    procedure MRL_NeverRun_SetRecord_PartAccess_Observe()
    begin
        Initialize();
        MRLSeed(1010); Clear(MRCurrentPage); MRLSet(1010, 0);
        Observer.Observe('db.before', MRLDatabase(1010));
        MRLSnapshot('fresh');
        Observer.Observe('db.after', MRLDatabase(1010));
        MRLFinish('MRL_NeverRun_SetRecord_PartAccess_Observe');
    end;


    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRL_Clear_AfterModal_PartAccess_Observe()
    begin
        Initialize();
        MRLSeed(1011); Clear(MRCurrentPage); MRLSet(1011, 0);
        Observer.Observe('first.answer', Format(MRCurrentPage.RunModal()));
        MRCurrentPage.Dirty(1); MRLSnapshot('before.clear');
        Observer.Observe('db.before', MRLDatabase(1011));
        Clear(MRCurrentPage); MRLSnapshot('after.clear');
        Observer.Observe('db.after', MRLDatabase(1011));
        MRLFinish('MRL_Clear_AfterModal_PartAccess_Observe');
    end;


    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRL_RepeatOK_SetDifferentRecord_Observe()
    begin
        Initialize();
        MRLSeed(1012); MRLSeed(1013); Clear(MRCurrentPage); MRLSet(1012, 0);
        Observer.Observe('first.answer', Format(MRCurrentPage.RunModal()));
        MRCurrentPage.Dirty(1); MRLSnapshot('first');
        Observer.Observe('first.db.before', MRLDatabase(1012));
        Observer.Observe('second.db.before', MRLDatabase(1013));
        MRLSet(1013, 0); Observer.Observe('second.answer', Format(MRCurrentPage.RunModal()));
        MRLSnapshot('second');
        Observer.Observe('first.db.after', MRLDatabase(1012));
        Observer.Observe('second.db.after', MRLDatabase(1013));
        MRLFinish('MRL_RepeatOK_SetDifferentRecord_Observe');
    end;


    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRL_RepeatCancel_SetDifferentRecord_Observe()
    begin
        Initialize();
        MRLSeed(1014); MRLSeed(1015); Clear(MRCurrentPage); MRLSet(1014, 1);
        MRCurrentPage.LookupMode := true;
        Observer.Observe('first.answer', Format(MRCurrentPage.RunModal())); MRLSnapshot('first');
        Observer.Observe('first.db.before', MRLDatabase(1014));
        Observer.Observe('second.db.before', MRLDatabase(1015));
        MRLSet(1015, 0); Observer.Observe('second.answer', Format(MRCurrentPage.RunModal()));
        MRLSnapshot('second');
        Observer.Observe('first.db.after', MRLDatabase(1014));
        Observer.Observe('second.db.after', MRLDatabase(1015));
        MRLFinish('MRL_RepeatCancel_SetDifferentRecord_Observe');
    end;


    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRL_FirstRunHandlerError_TryPartAccess_Observe()
    begin
        Initialize();
        MRLSeed(1016); Clear(MRCurrentPage); MRLSet(1016, 3);
        Observer.Observe('db.before', MRLDatabase(1016));
        MRLRunError(); MRLSnapshot('after.error');
        Observer.Observe('db.after', MRLDatabase(1016));
        MRLFinish('MRL_FirstRunHandlerError_TryPartAccess_Observe');
    end;


    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRL_SecondRunHandlerError_TryPartAccess_Observe()
    begin
        Initialize();
        MRLSeed(1017); MRLSeed(1018); Clear(MRCurrentPage); MRLSet(1017, 0);
        Observer.Observe('first.answer', Format(MRCurrentPage.RunModal()));
        MRCurrentPage.Dirty(1); MRLSnapshot('first');
        Observer.Observe('first.db.before', MRLDatabase(1017));
        Observer.Observe('second.db.before', MRLDatabase(1018));
        MRLSet(1018, 3); MRLRunError(); MRLSnapshot('after.error');
        Observer.Observe('first.db.after', MRLDatabase(1017));
        Observer.Observe('second.db.after', MRLDatabase(1018));
        MRLFinish('MRL_SecondRunHandlerError_TryPartAccess_Observe');
    end;


    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRL_RepeatOK_WithoutSetRecord_Observe()
    begin
        Initialize();
        MRLSeed(1019); Clear(MRCurrentPage); MRLSet(1019, 0);
        Observer.Observe('first.answer', Format(MRCurrentPage.RunModal()));
        MRCurrentPage.Dirty(1); MRLSnapshot('first');
        Observer.Observe('db.before', MRLDatabase(1019));
        Observer.Observe('second.answer', Format(MRCurrentPage.RunModal()));
        MRLSnapshot('second'); Observer.Observe('db.after', MRLDatabase(1019));
        MRLFinish('MRL_RepeatOK_WithoutSetRecord_Observe');
    end;


    local procedure MRFatalFinish(Identity: Text)
    var L: Codeunit "PAG Modal Writes Log";
    begin
        // These are after an outer Asserterror boundary, not an unrolled-back DB observation.
        Observer.Observe('phase.at-fatal', L.ReadPhase());
        Observer.Observe('trace.at-fatal', L.ReadTrace());
        Observer.Observe('capture.end', 'COMPLETE');
        MRExpect(Identity);
        Observer.Verify();
    end;

    local procedure MROwnHandler()
    var L: Codeunit "PAG Modal Writes Log"; Ok: Boolean; Code: Text;
    begin
        L.ResetTrace(); MRCurrentPage.Dirty(L.Side());
        L.Before(MRCurrentPage.Snapshot(L.Side()));
        L.Phase('before-own-operation');
        if L.Mode() = 5 then begin
            ClearLastError(); Ok := MRTryOperate(MRCurrentPage, L.Side(), L.Operation());
            if not Ok then Code := GetLastErrorCode();
            L.TryResult(Format(Ok), Code);
        end else MRCurrentPage.Operate(L.Side(), L.Operation());
        L.Phase('after-own-operation');
        L.Freeze(MRCurrentPage.Snapshot(L.Side()));
    end;

    local procedure MROwnRunOnly()
    var Answer: Action; L: Codeunit "PAG Modal Writes Log";
    begin
        Answer := MRCurrentPage.RunModal();
        L.Returned(Format(Answer));
    end;

    local procedure MROwnCase(Identity: Text; RowId: Integer; Side: Integer; Op: Integer; CatchOperation: Boolean)
    var H: Record "PAG Modal Writes Host"; R: Record "PAG Modal Writes Line";
        L: Codeunit "PAG Modal Writes Log"; Mode: Integer;
    begin
        Mode := 4; if CatchOperation then Mode := 5;
        Clear(MRCurrentPage); L.Configure(Mode, Side, Op, RowId);
        H.Id := RowId; H.Value := 'host-seed'; H.Insert(false);
        R.Id := RowId; R.Value := 'part-seed'; R.Insert(false);
        MRCurrentPage.SetRecord(H); MRCurrentPage.LookupMode := true;
        if CatchOperation and (Op <> 0) then begin
            // A normal return is a diagnostic Asserterror failure, never a confirmed fatal.
            // MROwnRunOnly has no Finish or artificial error that could be misidentified.
            asserterror MROwnRunOnly();
            Observer.ObserveError('fatal');
            Observer.Observe('case', Identity);
            MRFatalFinish(Identity);
            exit;
        end;
        MROwnRunOnly();
        Observer.Observe('case', Identity);
        Observer.Observe('returned', L.ReturnedText());
        Observer.Observe('before', L.BeforeText());
        Observer.Observe('after', L.AfterText());
        Observer.Observe('phase', L.ReadPhase());
        Observer.Observe('trace', L.OperationTrace());
        if CatchOperation then begin
            Observer.Observe('try.ok', L.TryOkText());
            Observer.Observe('try.error.code', L.TryCodeText());
        end;
        Observer.Observe('capture.end', 'COMPLETE');
        MRExpect(Identity);
        Observer.Verify();
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRO_OpenOwn_Host_UpdateFalse_Direct_Observe()
    begin
        Initialize();
        MROwnCase('MRO_OpenOwn_Host_UpdateFalse_Direct_Observe', 2010, 0, 0, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRO_OpenOwn_Host_UpdateFalse_Try_Observe()
    begin
        Initialize();
        MROwnCase('MRO_OpenOwn_Host_UpdateFalse_Try_Observe', 2011, 0, 0, true);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRO_OpenOwn_Host_UpdateTrue_Direct_Observe()
    begin
        Initialize();
        MROwnCase('MRO_OpenOwn_Host_UpdateTrue_Direct_Observe', 2012, 0, 1, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRO_OpenOwn_Host_UpdateTrue_Try_Observe()
    begin
        Initialize();
        MROwnCase('MRO_OpenOwn_Host_UpdateTrue_Try_Observe', 2013, 0, 1, true);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRO_OpenOwn_Host_SaveRecord_Direct_Observe()
    begin
        Initialize();
        MROwnCase('MRO_OpenOwn_Host_SaveRecord_Direct_Observe', 2014, 0, 2, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRO_OpenOwn_Host_SaveRecord_Try_Observe()
    begin
        Initialize();
        MROwnCase('MRO_OpenOwn_Host_SaveRecord_Try_Observe', 2015, 0, 2, true);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRO_OpenOwn_Part_UpdateFalse_Direct_Observe()
    begin
        Initialize();
        MROwnCase('MRO_OpenOwn_Part_UpdateFalse_Direct_Observe', 2016, 1, 0, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRO_OpenOwn_Part_UpdateFalse_Try_Observe()
    begin
        Initialize();
        MROwnCase('MRO_OpenOwn_Part_UpdateFalse_Try_Observe', 2017, 1, 0, true);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRO_OpenOwn_Part_UpdateTrue_Direct_Observe()
    begin
        Initialize();
        MROwnCase('MRO_OpenOwn_Part_UpdateTrue_Direct_Observe', 2018, 1, 1, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRO_OpenOwn_Part_UpdateTrue_Try_Observe()
    begin
        Initialize();
        MROwnCase('MRO_OpenOwn_Part_UpdateTrue_Try_Observe', 2019, 1, 1, true);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRO_OpenOwn_Part_SaveRecord_Direct_Observe()
    begin
        Initialize();
        MROwnCase('MRO_OpenOwn_Part_SaveRecord_Direct_Observe', 2020, 1, 2, false);
    end;

    [Test]
    [HandlerFunctions('MRDialogHandler')]
    procedure MRO_OpenOwn_Part_SaveRecord_Try_Observe()
    begin
        Initialize();
        MROwnCase('MRO_OpenOwn_Part_SaveRecord_Try_Observe', 2021, 1, 2, true);
    end;

    [ModalPageHandler]
    procedure MRFPartHandler(var P: TestPage "PAG Failed Part Host")
    var L: Codeunit "PAG Modal Writes Log";
    begin L.Mark('R.HANDLER.ERROR'); Error('default part handler failure'); end;

    [TryFunction]
    local procedure MRFTryRun(var Pg: Page "PAG Failed Part Host")
    var Answer: Action;
    begin Answer := Pg.RunModal(); end;

    [TryFunction]
    local procedure MRFTryRead(var Pg: Page "PAG Failed Part Host"; var Value: Text)
    begin Value := Pg.ReadChild(); end;

    local procedure MRFRead(var Pg: Page "PAG Failed Part Host"; LabelText: Text)
    var Value: Text; Ok: Boolean; Code: Text; ErrorText: Text; L: Codeunit "PAG Modal Writes Log";
    begin
        Observer.Observe(LabelText + '.trace.before', L.ReadTrace());
        ClearLastError(); Ok := MRFTryRead(Pg, Value);
        if not Ok then begin Code := GetLastErrorCode(); ErrorText := GetLastErrorText(); end;
        Observer.Observe(LabelText + '.ok', Format(Ok));
        Observer.Observe(LabelText + '.error.code', Code);
        Observer.Observe(LabelText + '.error.text', ErrorText);
        Observer.Observe(LabelText + '.value', Value);
        Observer.Observe(LabelText + '.trace.after', L.ReadTrace());
    end;

    local procedure MRFCase(Identity: Text; RowId: Integer; RunWithError: Boolean)
    var H: Record "PAG Modal Writes Host"; R: Record "PAG Modal Writes Line";
        Pg: Page "PAG Failed Part Host"; L: Codeunit "PAG Modal Writes Log";
        RunOk: Boolean; Code: Text; ErrorText: Text;
    begin
        L.Configure(0, 1, 0, RowId);
        H.Id := RowId; H.Value := 'host-seed'; H.Insert(false);
        R.Id := RowId; R.Value := 'part-seed'; R.Insert(false);
        Pg.SetRecord(H);
        if RunWithError then begin
            ClearLastError(); RunOk := MRFTryRun(Pg);
            if not RunOk then begin Code := GetLastErrorCode(); ErrorText := GetLastErrorText(); end;
            Observer.Observe('run.ok', Format(RunOk));
            Observer.Observe('run.error.code', Code);
            Observer.Observe('run.error.text', ErrorText);
        end;
        Observer.Observe('trace.before.getters', L.ReadTrace());
        MRFRead(Pg, 'first'); MRFRead(Pg, 'second');
        R.Get(RowId); Observer.Observe('db.part', R.Value);
        H.Get(RowId); Observer.Observe('db.host', H.Value);
        Observer.Observe('case', Identity);
        Observer.Observe('capture.end', 'COMPLETE');
        MRExpect(Identity);
        Observer.Verify();
    end;

    [Test]
    procedure MRF_NeverRun_DefaultPartInit_Observe()
    begin
        Initialize();
        MRFCase('MRF_NeverRun_DefaultPartInit_Observe', 3010, false);
    end;


    [Test]
    [HandlerFunctions('MRFPartHandler')]
    procedure MRF_HandlerError_DefaultPartInit_Observe()
    begin
        Initialize();
        MRFCase('MRF_HandlerError_DefaultPartInit_Observe', 3011, true);
    end;


    // Every literal below is derived from all three source-bound native pair streams.
    // This candidate is qualified only after full green runs of this exact source.
    local procedure MRExpect(Identity: Text)
    begin
        case Identity of
            'MR_OK_Host_UpdateFalse_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_OK_Host_UpdateFalse_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '1:host-dirty/db@1:host-seed');
                    Observer.Expect('after', '1:host-dirty/db@1:host-seed');
                    Observer.Expect('trace', 'H.DIRTY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_OK_Host_UpdateTrue_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_OK_Host_UpdateTrue_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '2:host-dirty/db@2:host-seed');
                    Observer.Expect('after', '2:host-dirty/db@2:host-dirty');
                    Observer.Expect('trace', 'H.DIRTY;H.PAGE.MODIFY;H.TABLE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_OK_Host_SaveRecord_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_OK_Host_SaveRecord_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '3:host-dirty/db@3:host-seed');
                    Observer.Expect('after', '3:host-dirty/db@3:host-dirty');
                    Observer.Expect('trace', 'H.DIRTY;H.PAGE.MODIFY;H.TABLE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_OK_Part_UpdateFalse_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_OK_Part_UpdateFalse_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '4:part-dirty/db@4:part-seed');
                    Observer.Expect('after', '4:part-dirty/db@4:part-seed');
                    Observer.Expect('trace', 'P.DIRTY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_OK_Part_UpdateTrue_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_OK_Part_UpdateTrue_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '5:part-dirty/db@5:part-seed');
                    Observer.Expect('after', '5:part-dirty/db@5:part-dirty');
                    Observer.Expect('trace', 'P.DIRTY;P.PAGE.MODIFY;P.TABLE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_OK_Part_SaveRecord_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_OK_Part_SaveRecord_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '6:part-dirty/db@6:part-seed');
                    Observer.Expect('after', '6:part-dirty/db@6:part-dirty');
                    Observer.Expect('trace', 'P.DIRTY;P.PAGE.MODIFY;P.TABLE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Cancel_Host_UpdateFalse_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_Cancel_Host_UpdateFalse_Direct_Observe');
                    Observer.Expect('returned', 'LookupCancel');
                    Observer.Expect('before', '7:host-dirty/db@7:host-seed');
                    Observer.Expect('after', '7:host-dirty/db@7:host-seed');
                    Observer.Expect('trace', 'H.DIRTY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Cancel_Host_UpdateTrue_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_Cancel_Host_UpdateTrue_Direct_Observe');
                    Observer.Expect('returned', 'LookupCancel');
                    Observer.Expect('before', '8:host-dirty/db@8:host-seed');
                    Observer.Expect('after', '8:host-dirty/db@8:host-dirty');
                    Observer.Expect('trace', 'H.DIRTY;H.PAGE.MODIFY;H.TABLE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Cancel_Host_SaveRecord_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_Cancel_Host_SaveRecord_Direct_Observe');
                    Observer.Expect('returned', 'LookupCancel');
                    Observer.Expect('before', '9:host-dirty/db@9:host-seed');
                    Observer.Expect('after', '9:host-dirty/db@9:host-dirty');
                    Observer.Expect('trace', 'H.DIRTY;H.PAGE.MODIFY;H.TABLE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Cancel_Part_UpdateFalse_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_Cancel_Part_UpdateFalse_Direct_Observe');
                    Observer.Expect('returned', 'LookupCancel');
                    Observer.Expect('before', '10:part-dirty/db@10:part-seed');
                    Observer.Expect('after', '10:part-dirty/db@10:part-seed');
                    Observer.Expect('trace', 'P.DIRTY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Cancel_Part_UpdateTrue_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_Cancel_Part_UpdateTrue_Direct_Observe');
                    Observer.Expect('returned', 'LookupCancel');
                    Observer.Expect('before', '11:part-dirty/db@11:part-seed');
                    Observer.Expect('after', '11:part-dirty/db@11:part-dirty');
                    Observer.Expect('trace', 'P.DIRTY;P.PAGE.MODIFY;P.TABLE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Cancel_Part_SaveRecord_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_Cancel_Part_SaveRecord_Direct_Observe');
                    Observer.Expect('returned', 'LookupCancel');
                    Observer.Expect('before', '12:part-dirty/db@12:part-seed');
                    Observer.Expect('after', '12:part-dirty/db@12:part-dirty');
                    Observer.Expect('trace', 'P.DIRTY;P.PAGE.MODIFY;P.TABLE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_OK_Host_UpdateFalse_Try_Observe':
                begin
                    Observer.Expect('case', 'MR_OK_Host_UpdateFalse_Try_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '13:host-dirty/db@13:host-seed');
                    Observer.Expect('try.ok', 'Yes');
                    Observer.Expect('try.error.code', '');
                    Observer.Expect('after', '13:host-dirty/db@13:host-seed');
                    Observer.Expect('trace', 'H.DIRTY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_OK_Host_UpdateTrue_Try_Observe':
                begin
                    Observer.Expect('case', 'MR_OK_Host_UpdateTrue_Try_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '14:host-dirty/db@14:host-seed');
                    Observer.Expect('fatal|text', 'Call to the function ''MODIFY'' is not allowed inside the call to ''MR_OK_Host_UpdateTrue_Try_Observe'' when it is used as a TryFunction.');
                    Observer.Expect('fatal|code', 'TryFunctionWrite');
                    Observer.Expect('phase.at-fatal', 'before-post-operation');
                    Observer.Expect('trace.at-fatal', 'H.DIRTY;H.PAGE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_OK_Host_SaveRecord_Try_Observe':
                begin
                    Observer.Expect('case', 'MR_OK_Host_SaveRecord_Try_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '15:host-dirty/db@15:host-seed');
                    Observer.Expect('fatal|text', 'Call to the function ''MODIFY'' is not allowed inside the call to ''MR_OK_Host_SaveRecord_Try_Observe'' when it is used as a TryFunction.');
                    Observer.Expect('fatal|code', 'TryFunctionWrite');
                    Observer.Expect('phase.at-fatal', 'before-post-operation');
                    Observer.Expect('trace.at-fatal', 'H.DIRTY;H.PAGE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_OK_Part_UpdateFalse_Try_Observe':
                begin
                    Observer.Expect('case', 'MR_OK_Part_UpdateFalse_Try_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '16:part-dirty/db@16:part-seed');
                    Observer.Expect('try.ok', 'Yes');
                    Observer.Expect('try.error.code', '');
                    Observer.Expect('after', '16:part-dirty/db@16:part-seed');
                    Observer.Expect('trace', 'P.DIRTY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_OK_Part_UpdateTrue_Try_Observe':
                begin
                    Observer.Expect('case', 'MR_OK_Part_UpdateTrue_Try_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '17:part-dirty/db@17:part-seed');
                    Observer.Expect('fatal|text', 'Call to the function ''MODIFY'' is not allowed inside the call to ''MR_OK_Part_UpdateTrue_Try_Observe'' when it is used as a TryFunction.');
                    Observer.Expect('fatal|code', 'TryFunctionWrite');
                    Observer.Expect('phase.at-fatal', 'before-post-operation');
                    Observer.Expect('trace.at-fatal', 'P.DIRTY;P.PAGE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_OK_Part_SaveRecord_Try_Observe':
                begin
                    Observer.Expect('case', 'MR_OK_Part_SaveRecord_Try_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '18:part-dirty/db@18:part-seed');
                    Observer.Expect('fatal|text', 'Call to the function ''MODIFY'' is not allowed inside the call to ''MR_OK_Part_SaveRecord_Try_Observe'' when it is used as a TryFunction.');
                    Observer.Expect('fatal|code', 'TryFunctionWrite');
                    Observer.Expect('phase.at-fatal', 'before-post-operation');
                    Observer.Expect('trace.at-fatal', 'P.DIRTY;P.PAGE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Cancel_Host_UpdateFalse_Try_Observe':
                begin
                    Observer.Expect('case', 'MR_Cancel_Host_UpdateFalse_Try_Observe');
                    Observer.Expect('returned', 'LookupCancel');
                    Observer.Expect('before', '19:host-dirty/db@19:host-seed');
                    Observer.Expect('try.ok', 'Yes');
                    Observer.Expect('try.error.code', '');
                    Observer.Expect('after', '19:host-dirty/db@19:host-seed');
                    Observer.Expect('trace', 'H.DIRTY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Cancel_Host_UpdateTrue_Try_Observe':
                begin
                    Observer.Expect('case', 'MR_Cancel_Host_UpdateTrue_Try_Observe');
                    Observer.Expect('returned', 'LookupCancel');
                    Observer.Expect('before', '20:host-dirty/db@20:host-seed');
                    Observer.Expect('fatal|text', 'Call to the function ''MODIFY'' is not allowed inside the call to ''MR_Cancel_Host_UpdateTrue_Try_Observe'' when it is used as a TryFunction.');
                    Observer.Expect('fatal|code', 'TryFunctionWrite');
                    Observer.Expect('phase.at-fatal', 'before-post-operation');
                    Observer.Expect('trace.at-fatal', 'H.DIRTY;H.PAGE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Cancel_Host_SaveRecord_Try_Observe':
                begin
                    Observer.Expect('case', 'MR_Cancel_Host_SaveRecord_Try_Observe');
                    Observer.Expect('returned', 'LookupCancel');
                    Observer.Expect('before', '21:host-dirty/db@21:host-seed');
                    Observer.Expect('fatal|text', 'Call to the function ''MODIFY'' is not allowed inside the call to ''MR_Cancel_Host_SaveRecord_Try_Observe'' when it is used as a TryFunction.');
                    Observer.Expect('fatal|code', 'TryFunctionWrite');
                    Observer.Expect('phase.at-fatal', 'before-post-operation');
                    Observer.Expect('trace.at-fatal', 'H.DIRTY;H.PAGE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Cancel_Part_UpdateFalse_Try_Observe':
                begin
                    Observer.Expect('case', 'MR_Cancel_Part_UpdateFalse_Try_Observe');
                    Observer.Expect('returned', 'LookupCancel');
                    Observer.Expect('before', '22:part-dirty/db@22:part-seed');
                    Observer.Expect('try.ok', 'Yes');
                    Observer.Expect('try.error.code', '');
                    Observer.Expect('after', '22:part-dirty/db@22:part-seed');
                    Observer.Expect('trace', 'P.DIRTY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Cancel_Part_UpdateTrue_Try_Observe':
                begin
                    Observer.Expect('case', 'MR_Cancel_Part_UpdateTrue_Try_Observe');
                    Observer.Expect('returned', 'LookupCancel');
                    Observer.Expect('before', '23:part-dirty/db@23:part-seed');
                    Observer.Expect('fatal|text', 'Call to the function ''MODIFY'' is not allowed inside the call to ''MR_Cancel_Part_UpdateTrue_Try_Observe'' when it is used as a TryFunction.');
                    Observer.Expect('fatal|code', 'TryFunctionWrite');
                    Observer.Expect('phase.at-fatal', 'before-post-operation');
                    Observer.Expect('trace.at-fatal', 'P.DIRTY;P.PAGE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Cancel_Part_SaveRecord_Try_Observe':
                begin
                    Observer.Expect('case', 'MR_Cancel_Part_SaveRecord_Try_Observe');
                    Observer.Expect('returned', 'LookupCancel');
                    Observer.Expect('before', '24:part-dirty/db@24:part-seed');
                    Observer.Expect('fatal|text', 'Call to the function ''MODIFY'' is not allowed inside the call to ''MR_Cancel_Part_SaveRecord_Try_Observe'' when it is used as a TryFunction.');
                    Observer.Expect('fatal|code', 'TryFunctionWrite');
                    Observer.Expect('phase.at-fatal', 'before-post-operation');
                    Observer.Expect('trace.at-fatal', 'P.DIRTY;P.PAGE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Open_Host_UpdateFalse_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_Open_Host_UpdateFalse_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '25:host-dirty/db@25:host-seed');
                    Observer.Expect('after', '25:host-dirty/db@25:host-seed');
                    Observer.Expect('trace.in-action', 'H.DIRTY;');
                    Observer.Expect('after.invoke', '25:host-seed/db@25:host-seed');
                    Observer.Expect('trace.after-invoke', 'H.DIRTY;H.AGR;H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Open_Host_UpdateTrue_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_Open_Host_UpdateTrue_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '26:host-dirty/db@26:host-seed');
                    Observer.Expect('after', '26:host-dirty/db@26:host-dirty');
                    Observer.Expect('trace.in-action', 'H.DIRTY;H.PAGE.MODIFY;H.TABLE.MODIFY;');
                    Observer.Expect('after.invoke', '26:host-dirty/db@26:host-dirty');
                    Observer.Expect('trace.after-invoke', 'H.DIRTY;H.PAGE.MODIFY;H.TABLE.MODIFY;H.AGR;H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Open_Host_SaveRecord_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_Open_Host_SaveRecord_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '27:host-dirty/db@27:host-seed');
                    Observer.Expect('after', '27:host-dirty/db@27:host-dirty');
                    Observer.Expect('trace.in-action', 'H.DIRTY;H.PAGE.MODIFY;H.TABLE.MODIFY;');
                    Observer.Expect('after.invoke', '27:host-dirty/db@27:host-dirty');
                    Observer.Expect('trace.after-invoke', 'H.DIRTY;H.PAGE.MODIFY;H.TABLE.MODIFY;H.AGR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Open_Part_UpdateFalse_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_Open_Part_UpdateFalse_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '28:part-dirty/db@28:part-seed');
                    Observer.Expect('after', '28:part-dirty/db@28:part-seed');
                    Observer.Expect('trace.in-action', 'P.DIRTY;');
                    Observer.Expect('after.invoke', '28:part-seed/db@28:part-seed');
                    Observer.Expect('trace.after-invoke', 'P.DIRTY;H.AGR;H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Open_Part_UpdateTrue_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_Open_Part_UpdateTrue_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '29:part-dirty/db@29:part-seed');
                    Observer.Expect('after', '29:part-dirty/db@29:part-dirty');
                    Observer.Expect('trace.in-action', 'P.DIRTY;P.PAGE.MODIFY;P.TABLE.MODIFY;');
                    Observer.Expect('after.invoke', '29:part-dirty/db@29:part-dirty');
                    Observer.Expect('trace.after-invoke', 'P.DIRTY;P.PAGE.MODIFY;P.TABLE.MODIFY;H.AGR;H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MR_Open_Part_SaveRecord_Direct_Observe':
                begin
                    Observer.Expect('case', 'MR_Open_Part_SaveRecord_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '30:part-dirty/db@30:part-seed');
                    Observer.Expect('after', '30:part-dirty/db@30:part-dirty');
                    Observer.Expect('trace.in-action', 'P.DIRTY;P.PAGE.MODIFY;P.TABLE.MODIFY;');
                    Observer.Expect('after.invoke', '30:part-dirty/db@30:part-dirty');
                    Observer.Expect('trace.after-invoke', 'P.DIRTY;P.PAGE.MODIFY;P.TABLE.MODIFY;H.AGR;H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRL_NeverRun_SetRecord_PartAccess_Observe':
                begin
                    Observer.Expect('db.before', '1010:H=host-seed;P=part-seed');
                    Observer.Expect('fresh.trace.before', '');
                    Observer.Expect('fresh.ok', 'Yes');
                    Observer.Expect('fresh.error.code', '');
                    Observer.Expect('fresh.value', '0:/db@1010:part-seed');
                    Observer.Expect('fresh.trace.after', '');
                    Observer.Expect('db.after', '1010:H=host-seed;P=part-seed');
                    Observer.Expect('case', 'MRL_NeverRun_SetRecord_PartAccess_Observe');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRL_Clear_AfterModal_PartAccess_Observe':
                begin
                    Observer.Expect('first.answer', 'OK');
                    Observer.Expect('before.clear.trace.before', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.DIRTY;');
                    Observer.Expect('before.clear.ok', 'Yes');
                    Observer.Expect('before.clear.error.code', '');
                    Observer.Expect('before.clear.value', '1011:part-dirty/db@1011:part-seed');
                    Observer.Expect('before.clear.trace.after', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.DIRTY;');
                    Observer.Expect('db.before', '1011:H=host-seed;P=part-seed');
                    Observer.Expect('after.clear.trace.before', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.DIRTY;');
                    Observer.Expect('after.clear.ok', 'Yes');
                    Observer.Expect('after.clear.error.code', '');
                    Observer.Expect('after.clear.value', '0:/db@1011:part-seed');
                    Observer.Expect('after.clear.trace.after', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.DIRTY;');
                    Observer.Expect('db.after', '1011:H=host-seed;P=part-seed');
                    Observer.Expect('case', 'MRL_Clear_AfterModal_PartAccess_Observe');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRL_RepeatOK_SetDifferentRecord_Observe':
                begin
                    Observer.Expect('first.answer', 'OK');
                    Observer.Expect('first.trace.before', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.DIRTY;');
                    Observer.Expect('first.ok', 'Yes');
                    Observer.Expect('first.error.code', '');
                    Observer.Expect('first.value', '1012:part-dirty/db@1012:part-seed');
                    Observer.Expect('first.trace.after', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.DIRTY;');
                    Observer.Expect('first.db.before', '1012:H=host-seed;P=part-seed');
                    Observer.Expect('second.db.before', '1013:H=host-seed;P=part-seed');
                    Observer.Expect('second.answer', 'OK');
                    Observer.Expect('second.trace.before', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('second.ok', 'Yes');
                    Observer.Expect('second.error.code', '');
                    Observer.Expect('second.value', '1013:part-seed/db@1013:part-seed');
                    Observer.Expect('second.trace.after', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('first.db.after', '1012:H=host-seed;P=part-seed');
                    Observer.Expect('second.db.after', '1013:H=host-seed;P=part-seed');
                    Observer.Expect('case', 'MRL_RepeatOK_SetDifferentRecord_Observe');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRL_RepeatCancel_SetDifferentRecord_Observe':
                begin
                    Observer.Expect('first.answer', 'LookupCancel');
                    Observer.Expect('first.trace.before', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.AGR;P.AGCR;H.AGR;H.AGCR;');
                    Observer.Expect('first.ok', 'Yes');
                    Observer.Expect('first.error.code', '');
                    Observer.Expect('first.value', '1014:part-seed/db@1014:part-seed');
                    Observer.Expect('first.trace.after', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.AGR;P.AGCR;H.AGR;H.AGCR;');
                    Observer.Expect('first.db.before', '1014:H=host-seed;P=part-seed');
                    Observer.Expect('second.db.before', '1015:H=host-seed;P=part-seed');
                    Observer.Expect('second.answer', 'LookupOK');
                    Observer.Expect('second.trace.before', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('second.ok', 'Yes');
                    Observer.Expect('second.error.code', '');
                    Observer.Expect('second.value', '1015:part-seed/db@1015:part-seed');
                    Observer.Expect('second.trace.after', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('first.db.after', '1014:H=host-seed;P=part-seed');
                    Observer.Expect('second.db.after', '1015:H=host-seed;P=part-seed');
                    Observer.Expect('case', 'MRL_RepeatCancel_SetDifferentRecord_Observe');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRL_FirstRunHandlerError_TryPartAccess_Observe':
                begin
                    Observer.Expect('db.before', '1016:H=host-seed;P=part-seed');
                    Observer.Expect('run.ok', 'No');
                    Observer.Expect('run.error.code', 'Dialog');
                    Observer.Expect('run.answer', 'None');
                    Observer.Expect('after.error.trace.before', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('after.error.ok', 'Yes');
                    Observer.Expect('after.error.error.code', '');
                    Observer.Expect('after.error.value', '0:/db@1016:part-seed');
                    Observer.Expect('after.error.trace.after', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('db.after', '1016:H=host-seed;P=part-seed');
                    Observer.Expect('case', 'MRL_FirstRunHandlerError_TryPartAccess_Observe');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRL_SecondRunHandlerError_TryPartAccess_Observe':
                begin
                    Observer.Expect('first.answer', 'OK');
                    Observer.Expect('first.trace.before', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.DIRTY;');
                    Observer.Expect('first.ok', 'Yes');
                    Observer.Expect('first.error.code', '');
                    Observer.Expect('first.value', '1017:part-dirty/db@1017:part-seed');
                    Observer.Expect('first.trace.after', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.DIRTY;');
                    Observer.Expect('first.db.before', '1017:H=host-seed;P=part-seed');
                    Observer.Expect('second.db.before', '1018:H=host-seed;P=part-seed');
                    Observer.Expect('run.ok', 'No');
                    Observer.Expect('run.error.code', 'Dialog');
                    Observer.Expect('run.answer', 'None');
                    Observer.Expect('after.error.trace.before', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('after.error.ok', 'Yes');
                    Observer.Expect('after.error.error.code', '');
                    Observer.Expect('after.error.value', '0:/db@1018:part-seed');
                    Observer.Expect('after.error.trace.after', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('first.db.after', '1017:H=host-seed;P=part-seed');
                    Observer.Expect('second.db.after', '1018:H=host-seed;P=part-seed');
                    Observer.Expect('case', 'MRL_SecondRunHandlerError_TryPartAccess_Observe');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRL_RepeatOK_WithoutSetRecord_Observe':
                begin
                    Observer.Expect('first.answer', 'OK');
                    Observer.Expect('first.trace.before', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.DIRTY;');
                    Observer.Expect('first.ok', 'Yes');
                    Observer.Expect('first.error.code', '');
                    Observer.Expect('first.value', '1019:part-dirty/db@1019:part-seed');
                    Observer.Expect('first.trace.after', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.DIRTY;');
                    Observer.Expect('db.before', '1019:H=host-seed;P=part-seed');
                    Observer.Expect('second.answer', 'OK');
                    Observer.Expect('second.trace.before', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.DIRTY;H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('second.ok', 'Yes');
                    Observer.Expect('second.error.code', '');
                    Observer.Expect('second.value', '1019:part-seed/db@1019:part-seed');
                    Observer.Expect('second.trace.after', 'H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;P.DIRTY;H.AGR;H.AGCR;P.AGR;P.AGR;P.AGCR;');
                    Observer.Expect('db.after', '1019:H=host-seed;P=part-seed');
                    Observer.Expect('case', 'MRL_RepeatOK_WithoutSetRecord_Observe');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRO_OpenOwn_Host_UpdateFalse_Direct_Observe':
                begin
                    Observer.Expect('case', 'MRO_OpenOwn_Host_UpdateFalse_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '2010:host-dirty/db@2010:host-seed');
                    Observer.Expect('after', '2010:host-dirty/db@2010:host-seed');
                    Observer.Expect('phase', 'after-own-operation');
                    Observer.Expect('trace', 'H.DIRTY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRO_OpenOwn_Host_UpdateFalse_Try_Observe':
                begin
                    Observer.Expect('case', 'MRO_OpenOwn_Host_UpdateFalse_Try_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '2011:host-dirty/db@2011:host-seed');
                    Observer.Expect('after', '2011:host-dirty/db@2011:host-seed');
                    Observer.Expect('phase', 'after-own-operation');
                    Observer.Expect('trace', 'H.DIRTY;');
                    Observer.Expect('try.ok', 'Yes');
                    Observer.Expect('try.error.code', '');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRO_OpenOwn_Host_UpdateTrue_Direct_Observe':
                begin
                    Observer.Expect('case', 'MRO_OpenOwn_Host_UpdateTrue_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '2012:host-dirty/db@2012:host-seed');
                    Observer.Expect('after', '2012:host-dirty/db@2012:host-dirty');
                    Observer.Expect('phase', 'after-own-operation');
                    Observer.Expect('trace', 'H.DIRTY;H.PAGE.MODIFY;H.TABLE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRO_OpenOwn_Host_UpdateTrue_Try_Observe':
                begin
                    Observer.Expect('fatal|text', 'Call to the function ''MODIFY'' is not allowed inside the call to ''MRDialogHandler'' when it is used as a TryFunction.');
                    Observer.Expect('fatal|code', 'TryFunctionWrite');
                    Observer.Expect('case', 'MRO_OpenOwn_Host_UpdateTrue_Try_Observe');
                    Observer.Expect('phase.at-fatal', 'before-own-operation');
                    Observer.Expect('trace.at-fatal', 'H.DIRTY;H.PAGE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRO_OpenOwn_Host_SaveRecord_Direct_Observe':
                begin
                    Observer.Expect('case', 'MRO_OpenOwn_Host_SaveRecord_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '2014:host-dirty/db@2014:host-seed');
                    Observer.Expect('after', '2014:host-dirty/db@2014:host-dirty');
                    Observer.Expect('phase', 'after-own-operation');
                    Observer.Expect('trace', 'H.DIRTY;H.PAGE.MODIFY;H.TABLE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRO_OpenOwn_Host_SaveRecord_Try_Observe':
                begin
                    Observer.Expect('fatal|text', 'Call to the function ''MODIFY'' is not allowed inside the call to ''MRDialogHandler'' when it is used as a TryFunction.');
                    Observer.Expect('fatal|code', 'TryFunctionWrite');
                    Observer.Expect('case', 'MRO_OpenOwn_Host_SaveRecord_Try_Observe');
                    Observer.Expect('phase.at-fatal', 'before-own-operation');
                    Observer.Expect('trace.at-fatal', 'H.DIRTY;H.PAGE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRO_OpenOwn_Part_UpdateFalse_Direct_Observe':
                begin
                    Observer.Expect('case', 'MRO_OpenOwn_Part_UpdateFalse_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '2016:part-dirty/db@2016:part-seed');
                    Observer.Expect('after', '2016:part-dirty/db@2016:part-seed');
                    Observer.Expect('phase', 'after-own-operation');
                    Observer.Expect('trace', 'P.DIRTY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRO_OpenOwn_Part_UpdateFalse_Try_Observe':
                begin
                    Observer.Expect('case', 'MRO_OpenOwn_Part_UpdateFalse_Try_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '2017:part-dirty/db@2017:part-seed');
                    Observer.Expect('after', '2017:part-dirty/db@2017:part-seed');
                    Observer.Expect('phase', 'after-own-operation');
                    Observer.Expect('trace', 'P.DIRTY;');
                    Observer.Expect('try.ok', 'Yes');
                    Observer.Expect('try.error.code', '');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRO_OpenOwn_Part_UpdateTrue_Direct_Observe':
                begin
                    Observer.Expect('case', 'MRO_OpenOwn_Part_UpdateTrue_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '2018:part-dirty/db@2018:part-seed');
                    Observer.Expect('after', '2018:part-dirty/db@2018:part-dirty');
                    Observer.Expect('phase', 'after-own-operation');
                    Observer.Expect('trace', 'P.DIRTY;P.PAGE.MODIFY;P.TABLE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRO_OpenOwn_Part_UpdateTrue_Try_Observe':
                begin
                    Observer.Expect('fatal|text', 'Call to the function ''MODIFY'' is not allowed inside the call to ''MRDialogHandler'' when it is used as a TryFunction.');
                    Observer.Expect('fatal|code', 'TryFunctionWrite');
                    Observer.Expect('case', 'MRO_OpenOwn_Part_UpdateTrue_Try_Observe');
                    Observer.Expect('phase.at-fatal', 'before-own-operation');
                    Observer.Expect('trace.at-fatal', 'P.DIRTY;P.PAGE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRO_OpenOwn_Part_SaveRecord_Direct_Observe':
                begin
                    Observer.Expect('case', 'MRO_OpenOwn_Part_SaveRecord_Direct_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('before', '2020:part-dirty/db@2020:part-seed');
                    Observer.Expect('after', '2020:part-dirty/db@2020:part-dirty');
                    Observer.Expect('phase', 'after-own-operation');
                    Observer.Expect('trace', 'P.DIRTY;P.PAGE.MODIFY;P.TABLE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRO_OpenOwn_Part_SaveRecord_Try_Observe':
                begin
                    Observer.Expect('fatal|text', 'Call to the function ''MODIFY'' is not allowed inside the call to ''MRDialogHandler'' when it is used as a TryFunction.');
                    Observer.Expect('fatal|code', 'TryFunctionWrite');
                    Observer.Expect('case', 'MRO_OpenOwn_Part_SaveRecord_Try_Observe');
                    Observer.Expect('phase.at-fatal', 'before-own-operation');
                    Observer.Expect('trace.at-fatal', 'P.DIRTY;P.PAGE.MODIFY;');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRF_NeverRun_DefaultPartInit_Observe':
                begin
                    Observer.Expect('trace.before.getters', '');
                    Observer.Expect('first.trace.before', '');
                    Observer.Expect('first.ok', 'Yes');
                    Observer.Expect('first.error.code', '');
                    Observer.Expect('first.error.text', '');
                    Observer.Expect('first.value', '1/0/0/');
                    Observer.Expect('first.trace.after', 'Q.INIT;');
                    Observer.Expect('second.trace.before', 'Q.INIT;');
                    Observer.Expect('second.ok', 'Yes');
                    Observer.Expect('second.error.code', '');
                    Observer.Expect('second.error.text', '');
                    Observer.Expect('second.value', '1/0/0/');
                    Observer.Expect('second.trace.after', 'Q.INIT;');
                    Observer.Expect('db.part', 'part-seed');
                    Observer.Expect('db.host', 'host-seed');
                    Observer.Expect('case', 'MRF_NeverRun_DefaultPartInit_Observe');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRF_HandlerError_DefaultPartInit_Observe':
                begin
                    Observer.Expect('run.ok', 'No');
                    Observer.Expect('run.error.code', 'Dialog');
                    Observer.Expect('run.error.text', 'default part handler failure');
                    Observer.Expect('trace.before.getters', 'Q.INIT;R.OPEN;Q.OPEN;Q.AGR;Q.AGR;Q.AGCR;R.HANDLER.ERROR;');
                    Observer.Expect('first.trace.before', 'Q.INIT;R.OPEN;Q.OPEN;Q.AGR;Q.AGR;Q.AGCR;R.HANDLER.ERROR;');
                    Observer.Expect('first.ok', 'Yes');
                    Observer.Expect('first.error.code', '');
                    Observer.Expect('first.error.text', '');
                    Observer.Expect('first.value', '1/0/0/');
                    Observer.Expect('first.trace.after', 'Q.INIT;R.OPEN;Q.OPEN;Q.AGR;Q.AGR;Q.AGCR;R.HANDLER.ERROR;Q.INIT;');
                    Observer.Expect('second.trace.before', 'Q.INIT;R.OPEN;Q.OPEN;Q.AGR;Q.AGR;Q.AGCR;R.HANDLER.ERROR;Q.INIT;');
                    Observer.Expect('second.ok', 'Yes');
                    Observer.Expect('second.error.code', '');
                    Observer.Expect('second.error.text', '');
                    Observer.Expect('second.value', '1/0/0/');
                    Observer.Expect('second.trace.after', 'Q.INIT;R.OPEN;Q.OPEN;Q.AGR;Q.AGR;Q.AGCR;R.HANDLER.ERROR;Q.INIT;');
                    Observer.Expect('db.part', 'part-seed');
                    Observer.Expect('db.host', 'host-seed');
                    Observer.Expect('case', 'MRF_HandlerError_DefaultPartInit_Observe');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            else Error('Unknown modal return contract: %1', Identity);
        end;
    end;

    var MRHPage: Page "PAG Hidden Return Host"; MRHOpenedA: Text; MRHOpenedAId: Integer;
        MRHVisibleBId: Integer; MRHAVisible: Boolean; MRHBVisible: Boolean; MRHBeforeClose: Text;

    [ModalPageHandler]
    procedure MRHHandler(var P: TestPage "PAG Hidden Return Host")
    var L: Codeunit "PAG Modal Writes Log";
    begin
        MRHOpenedAId := P.A.Id.AsInteger();
        MRHOpenedA := MRHPage.HiddenSnapshot();
        P.ShowB.SetValue(true);
        MRHAVisible := P.A.Visible(); MRHBVisible := P.B.Visible();
        MRHVisibleBId := P.B.Id.AsInteger();
        MRHBeforeClose := L.ReadTrace();
        P.OK().Invoke();
    end;

    local procedure MRHCase(Identity: Text; RowId: Integer; Op: Integer)
    var H: Record "PAG Modal Writes Host"; R: Record "PAG Modal Writes Line";
        L: Codeunit "PAG Modal Writes Log"; Answer: Action;
    begin
        Clear(MRHPage); L.Configure(0, 1, Op, RowId);
        MRHOpenedA := ''; MRHOpenedAId := -1; MRHVisibleBId := -1;
        MRHAVisible := true; MRHBVisible := false; MRHBeforeClose := '';
        H.Id := RowId; H.Value := 'host-seed'; H.Insert(false);
        R.Id := RowId; R.Value := 'part-seed'; R.Insert(false);
        MRHPage.SetRecord(H); MRHPage.LookupMode := true; Answer := MRHPage.RunModal();
        Observer.Observe('case', Identity); Observer.Observe('returned', Format(Answer));
        Observer.Observe('opened.a.id', Format(MRHOpenedAId));
        Observer.Observe('opened.a.snapshot', MRHOpenedA);
        Observer.Observe('a.visible.after.switch', Format(MRHAVisible));
        Observer.Observe('b.visible.after.switch', Format(MRHBVisible));
        Observer.Observe('visible.b.id', Format(MRHVisibleBId));
        Observer.Observe('before.close.trace', MRHBeforeClose);
        Observer.Observe('after.close.trace', L.ReadTrace());
        L.ResetTrace(); Observer.Observe('before.dirty.trace', L.ReadTrace());
        MRHPage.DirtyHidden();
        Observer.Observe('before.hidden', MRHPage.HiddenSnapshot());
        Observer.Observe('before.visible', MRHPage.VisibleSnapshot());
        MRHPage.OperateHidden(Op);
        Observer.Observe('operation.trace', L.ReadTrace());
        Observer.Observe('after.hidden', MRHPage.HiddenSnapshot());
        Observer.Observe('after.visible', MRHPage.VisibleSnapshot());
        Observer.Observe('after.read.trace', L.ReadTrace());
        H.Get(RowId); Observer.Observe('db.host', H.Value);
        Observer.Observe('capture.end', 'COMPLETE'); MRViewExpect(Identity); Observer.Verify();
    end;

    [Test]
    [HandlerFunctions('MRHHandler')]
    procedure MRH_AfterModal_Hidden_UpdateFalse_Observe()
    begin
        Initialize();
        MRHCase('MRH_AfterModal_Hidden_UpdateFalse_Observe', 4010, 0);
    end;


    [Test]
    [HandlerFunctions('MRHHandler')]
    procedure MRH_AfterModal_Hidden_UpdateTrue_Observe()
    begin
        Initialize();
        MRHCase('MRH_AfterModal_Hidden_UpdateTrue_Observe', 4011, 1);
    end;


    [Test]
    [HandlerFunctions('MRHHandler')]
    procedure MRH_AfterModal_Hidden_SaveRecord_Observe()
    begin
        Initialize();
        MRHCase('MRH_AfterModal_Hidden_SaveRecord_Observe', 4012, 2);
    end;

    var RRPage: Page "PAG Modal Root Abort"; RRMode: Integer; RRAnswer: Action;
        RRInitialId: Integer; RRNextId: Integer; RRNextResult: Boolean; RRNextReturned: Boolean;
        RRHandlerRoot: Text; RRHandlerTrace: Text; RRBeforeReturnPhase: Text; RRBeforeReturnTrace: Text;
        RRInnerOk: Boolean; RRInnerCode: Text; RRInnerText: Text;

    [ModalPageHandler]
    procedure RRHandler(var P: TestPage "PAG Modal Root Abort")
    var L: Codeunit "PAG Modal Writes Log";
    begin
        RRInitialId := P.Id.AsInteger();
        RRHandlerRoot := RRPage.ReadRoot(); RRHandlerTrace := L.ReadTrace();
        if (RRMode in [2, 3]) and (RRInitialId <> L.RowId()) then
            Error('RR precondition: expected initial row %1, got %2', L.RowId(), RRInitialId);
        case RRMode of
            0: P.OK().Invoke();
            1: begin L.Mark('RR.HANDLER.ERROR'); Error('direct root handler failure'); end;
            2: begin
                L.Phase('row-error-armed'); L.Mark('RR.NEXT.ENTER');
                RRNextResult := P.Next(); RRNextReturned := true; RRNextId := P.Id.AsInteger(); L.Mark('RR.NEXT.RETURN');
            end;
            3: begin
                L.Phase('row-error-armed'); L.Mark('RR.TRY.NEXT.ENTER');
                ClearLastError(); RRInnerOk := RRTryNext(P);
                if not RRInnerOk then begin RRInnerCode := GetLastErrorCode(); RRInnerText := GetLastErrorText(); end;
                L.Phase('row-error-caught'); L.Mark('RR.TRY.NEXT.RETURN');
            end;
        end;
        L.Mark('RR.HANDLER.RETURN'); RRBeforeReturnPhase := L.ReadPhase(); RRBeforeReturnTrace := L.ReadTrace();
    end;

    [TryFunction]
    local procedure RRTryNext(var P: TestPage "PAG Modal Root Abort")
    begin RRNextResult := P.Next(); RRNextReturned := true; RRNextId := P.Id.AsInteger(); end;
    [TryFunction]
    local procedure RRTryRun()
    begin RRAnswer := RRPage.RunModal(); end;
    [TryFunction]
    local procedure RRTryGet(Root: Boolean; var Value: Text)
    begin if Root then Value := RRPage.ReadRoot() else Value := RRPage.ReadChild(); end;

    local procedure RRGet(LabelText: Text; Root: Boolean)
    var Value: Text; Ok: Boolean; Code: Text; ErrorText: Text; L: Codeunit "PAG Modal Writes Log";
    begin
        Observer.Observe(LabelText + '.trace.before', L.ReadTrace());
        ClearLastError(); Ok := RRTryGet(Root, Value);
        if not Ok then begin Code := GetLastErrorCode(); ErrorText := GetLastErrorText(); end;
        Observer.Observe(LabelText + '.ok', Format(Ok));
        Observer.Observe(LabelText + '.error.code', Code); Observer.Observe(LabelText + '.error.text', ErrorText);
        Observer.Observe(LabelText + '.value', Value); Observer.Observe(LabelText + '.trace.after', L.ReadTrace());
    end;

    local procedure RRCase(Identity: Text; RowId: Integer; Mode: Integer)
    var H: Record "PAG Modal Writes Host"; R: Record "PAG Modal Writes Line"; L: Codeunit "PAG Modal Writes Log";
        RunOk: Boolean; Code: Text; ErrorText: Text;
    begin
        Clear(RRPage); RRMode := Mode; Clear(RRAnswer); RRInitialId := -1; RRNextId := -1;
        RRNextResult := false; RRNextReturned := false; RRHandlerRoot := ''; RRHandlerTrace := ''; RRBeforeReturnPhase := ''; RRBeforeReturnTrace := '';
        RRInnerOk := false; RRInnerCode := ''; RRInnerText := ''; L.Configure(0, 1, 0, RowId);
        H.Id := RowId; H.Value := 'host-first'; H.Insert(false);
        H.Id := RowId + 1; H.Value := 'host-second'; H.Insert(false);
        R.Id := RowId; R.Value := 'part-first'; R.Insert(false);
        R.Id := RowId + 1; R.Value := 'part-second'; R.Insert(false);
        H.Get(RowId); RRPage.SetRecord(H); RRPage.Prepare(); RRPage.LookupMode := true;
        Observer.Observe('prepared.root', RRPage.ReadRoot());
        ClearLastError(); RunOk := RRTryRun();
        if not RunOk then begin Code := GetLastErrorCode(); ErrorText := GetLastErrorText(); end;
        Observer.Observe('run.ok', Format(RunOk)); Observer.Observe('run.error.code', Code); Observer.Observe('run.error.text', ErrorText);
        if RunOk then Observer.Observe('run.answer', Format(RRAnswer));
        Observer.Observe('trace.after.run', L.ReadTrace());
        // Root is frozen BEFORE part access can cause any lazy initialization.
        RRGet('root', true); RRGet('part.first', false); RRGet('part.second', false);
        Observer.Observe('handler.initial.id', Format(RRInitialId)); Observer.Observe('handler.root', RRHandlerRoot);
        Observer.Observe('handler.trace', RRHandlerTrace); Observer.Observe('next.target.id', Format(RowId + 1));
        Observer.Observe('next.returned', Format(RRNextReturned));
        if RRNextReturned then Observer.Observe('next.return.value', Format(RRNextResult)); Observer.Observe('next.reached.id', Format(RRNextId));
        Observer.Observe('inner.ok', Format(RRInnerOk)); Observer.Observe('inner.error.code', RRInnerCode); Observer.Observe('inner.error.text', RRInnerText);
        Observer.Observe('handler.before.return.phase', RRBeforeReturnPhase); Observer.Observe('handler.before.return.trace', RRBeforeReturnTrace);
        H.Get(RowId); Observer.Observe('db.host.first', H.Value); H.Get(RowId + 1); Observer.Observe('db.host.second', H.Value);
        R.Get(RowId); Observer.Observe('db.part.first', R.Value); R.Get(RowId + 1); Observer.Observe('db.part.second', R.Value);
        Observer.Observe('case', Identity); Observer.Observe('capture.end', 'COMPLETE'); MRViewExpect(Identity); Observer.Verify();
    end;

    [Test]
    [HandlerFunctions('RRHandler')]
    procedure RR_NormalOK_Observe()
    begin Initialize(); RRCase('RR_NormalOK_Observe', 5010, 0); end;



    [Test]
    [HandlerFunctions('RRHandler')]
    procedure RR_HandlerDialog_Observe()
    begin Initialize(); RRCase('RR_HandlerDialog_Observe', 5020, 1); end;



    [Test]
    [HandlerFunctions('RRHandler')]
    procedure RR_RowInvokeDirect_Observe()
    begin Initialize(); RRCase('RR_RowInvokeDirect_Observe', 5030, 2); end;



    [Test]
    [HandlerFunctions('RRHandler')]
    procedure RR_RowInvokeTryCaught_Observe()
    begin Initialize(); RRCase('RR_RowInvokeTryCaught_Observe', 5040, 3); end;



    // Exact ordered pairs retained from all three source-bound native runs.
    local procedure MRViewExpect(Identity: Text)
    begin
        case Identity of
            'MRH_AfterModal_Hidden_UpdateFalse_Observe':
                begin
                    Observer.Expect('case', 'MRH_AfterModal_Hidden_UpdateFalse_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('opened.a.id', '4010');
                    Observer.Expect('opened.a.snapshot', '4010:part-seed/db@4010:part-seed');
                    Observer.Expect('a.visible.after.switch', 'No');
                    Observer.Expect('b.visible.after.switch', 'Yes');
                    Observer.Expect('visible.b.id', '4010');
                    Observer.Expect('before.close.trace', 'HA.INIT;HB.INIT;HP.OPEN;HA.OPEN;HB.OPEN;HP.AGR;HP.AGCR;HA.AGR;HA.AGR;HA.AGCR;HB.AGR;HB.AGR;HB.AGCR;HB.AGR;HB.AGR;HB.AGCR;');
                    Observer.Expect('after.close.trace', 'HA.INIT;HB.INIT;HP.OPEN;HA.OPEN;HB.OPEN;HP.AGR;HP.AGCR;HA.AGR;HA.AGR;HA.AGCR;HB.AGR;HB.AGR;HB.AGCR;HB.AGR;HB.AGR;HB.AGCR;HP.CLOSE;');
                    Observer.Expect('before.dirty.trace', '');
                    Observer.Expect('before.hidden', '4010:part-dirty/db@4010:part-seed');
                    Observer.Expect('before.visible', '4010:part-seed/db@4010:part-seed');
                    Observer.Expect('operation.trace', 'HA.DIRTY;');
                    Observer.Expect('after.hidden', '4010:part-dirty/db@4010:part-seed');
                    Observer.Expect('after.visible', '4010:part-seed/db@4010:part-seed');
                    Observer.Expect('after.read.trace', 'HA.DIRTY;');
                    Observer.Expect('db.host', 'host-seed');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRH_AfterModal_Hidden_UpdateTrue_Observe':
                begin
                    Observer.Expect('case', 'MRH_AfterModal_Hidden_UpdateTrue_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('opened.a.id', '4011');
                    Observer.Expect('opened.a.snapshot', '4011:part-seed/db@4011:part-seed');
                    Observer.Expect('a.visible.after.switch', 'No');
                    Observer.Expect('b.visible.after.switch', 'Yes');
                    Observer.Expect('visible.b.id', '4011');
                    Observer.Expect('before.close.trace', 'HA.INIT;HB.INIT;HP.OPEN;HA.OPEN;HB.OPEN;HP.AGR;HP.AGCR;HA.AGR;HA.AGR;HA.AGCR;HB.AGR;HB.AGR;HB.AGCR;HB.AGR;HB.AGR;HB.AGCR;');
                    Observer.Expect('after.close.trace', 'HA.INIT;HB.INIT;HP.OPEN;HA.OPEN;HB.OPEN;HP.AGR;HP.AGCR;HA.AGR;HA.AGR;HA.AGCR;HB.AGR;HB.AGR;HB.AGCR;HB.AGR;HB.AGR;HB.AGCR;HP.CLOSE;');
                    Observer.Expect('before.dirty.trace', '');
                    Observer.Expect('before.hidden', '4011:part-dirty/db@4011:part-seed');
                    Observer.Expect('before.visible', '4011:part-seed/db@4011:part-seed');
                    Observer.Expect('operation.trace', 'HA.DIRTY;HA.PAGE.MODIFY;P.TABLE.MODIFY;');
                    Observer.Expect('after.hidden', '4011:part-dirty/db@4011:part-dirty');
                    Observer.Expect('after.visible', '4011:part-seed/db@4011:part-dirty');
                    Observer.Expect('after.read.trace', 'HA.DIRTY;HA.PAGE.MODIFY;P.TABLE.MODIFY;');
                    Observer.Expect('db.host', 'host-seed');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'MRH_AfterModal_Hidden_SaveRecord_Observe':
                begin
                    Observer.Expect('case', 'MRH_AfterModal_Hidden_SaveRecord_Observe');
                    Observer.Expect('returned', 'LookupOK');
                    Observer.Expect('opened.a.id', '4012');
                    Observer.Expect('opened.a.snapshot', '4012:part-seed/db@4012:part-seed');
                    Observer.Expect('a.visible.after.switch', 'No');
                    Observer.Expect('b.visible.after.switch', 'Yes');
                    Observer.Expect('visible.b.id', '4012');
                    Observer.Expect('before.close.trace', 'HA.INIT;HB.INIT;HP.OPEN;HA.OPEN;HB.OPEN;HP.AGR;HP.AGCR;HA.AGR;HA.AGR;HA.AGCR;HB.AGR;HB.AGR;HB.AGCR;HB.AGR;HB.AGR;HB.AGCR;');
                    Observer.Expect('after.close.trace', 'HA.INIT;HB.INIT;HP.OPEN;HA.OPEN;HB.OPEN;HP.AGR;HP.AGCR;HA.AGR;HA.AGR;HA.AGCR;HB.AGR;HB.AGR;HB.AGCR;HB.AGR;HB.AGR;HB.AGCR;HP.CLOSE;');
                    Observer.Expect('before.dirty.trace', '');
                    Observer.Expect('before.hidden', '4012:part-dirty/db@4012:part-seed');
                    Observer.Expect('before.visible', '4012:part-seed/db@4012:part-seed');
                    Observer.Expect('operation.trace', 'HA.DIRTY;HA.PAGE.MODIFY;P.TABLE.MODIFY;');
                    Observer.Expect('after.hidden', '4012:part-dirty/db@4012:part-dirty');
                    Observer.Expect('after.visible', '4012:part-seed/db@4012:part-dirty');
                    Observer.Expect('after.read.trace', 'HA.DIRTY;HA.PAGE.MODIFY;P.TABLE.MODIFY;');
                    Observer.Expect('db.host', 'host-seed');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'RR_NormalOK_Observe':
                begin
                    Observer.Expect('prepared.root', '1/0/prepared/5010/host-first');
                    Observer.Expect('run.ok', 'Yes');
                    Observer.Expect('run.error.code', '');
                    Observer.Expect('run.error.text', '');
                    Observer.Expect('run.answer', 'LookupOK');
                    Observer.Expect('trace.after.run', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5010;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.RETURN;');
                    Observer.Expect('root.trace.before', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5010;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.RETURN;');
                    Observer.Expect('root.ok', 'Yes');
                    Observer.Expect('root.error.code', '');
                    Observer.Expect('root.error.text', '');
                    Observer.Expect('root.value', '1/1/opened/5010/host-first');
                    Observer.Expect('root.trace.after', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5010;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.RETURN;');
                    Observer.Expect('part.first.trace.before', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5010;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.RETURN;');
                    Observer.Expect('part.first.ok', 'Yes');
                    Observer.Expect('part.first.error.code', '');
                    Observer.Expect('part.first.error.text', '');
                    Observer.Expect('part.first.value', '1/1/5010/part-first');
                    Observer.Expect('part.first.trace.after', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5010;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.RETURN;');
                    Observer.Expect('part.second.trace.before', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5010;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.RETURN;');
                    Observer.Expect('part.second.ok', 'Yes');
                    Observer.Expect('part.second.error.code', '');
                    Observer.Expect('part.second.error.text', '');
                    Observer.Expect('part.second.value', '1/1/5010/part-first');
                    Observer.Expect('part.second.trace.after', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5010;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.RETURN;');
                    Observer.Expect('handler.initial.id', '5010');
                    Observer.Expect('handler.root', '1/1/opened/5010/host-first');
                    Observer.Expect('handler.trace', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5010;Q.AGR;Q.AGR;Q.AGCR;');
                    Observer.Expect('next.target.id', '5011');
                    Observer.Expect('next.returned', 'No');
                    Observer.Expect('next.reached.id', '-1');
                    Observer.Expect('inner.ok', 'No');
                    Observer.Expect('inner.error.code', '');
                    Observer.Expect('inner.error.text', '');
                    Observer.Expect('handler.before.return.phase', '');
                    Observer.Expect('handler.before.return.trace', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5010;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.RETURN;');
                    Observer.Expect('db.host.first', 'host-first');
                    Observer.Expect('db.host.second', 'host-second');
                    Observer.Expect('db.part.first', 'part-first');
                    Observer.Expect('db.part.second', 'part-second');
                    Observer.Expect('case', 'RR_NormalOK_Observe');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'RR_HandlerDialog_Observe':
                begin
                    Observer.Expect('prepared.root', '1/0/prepared/5020/host-first');
                    Observer.Expect('run.ok', 'No');
                    Observer.Expect('run.error.code', 'Dialog');
                    Observer.Expect('run.error.text', 'direct root handler failure');
                    Observer.Expect('trace.after.run', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5020;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.ERROR;');
                    Observer.Expect('root.trace.before', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5020;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.ERROR;');
                    Observer.Expect('root.ok', 'Yes');
                    Observer.Expect('root.error.code', '');
                    Observer.Expect('root.error.text', '');
                    Observer.Expect('root.value', '1/0/initialized/0/');
                    Observer.Expect('root.trace.after', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5020;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.ERROR;RR.INIT;');
                    Observer.Expect('part.first.trace.before', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5020;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.ERROR;RR.INIT;');
                    Observer.Expect('part.first.ok', 'Yes');
                    Observer.Expect('part.first.error.code', '');
                    Observer.Expect('part.first.error.text', '');
                    Observer.Expect('part.first.value', '1/0/0/');
                    Observer.Expect('part.first.trace.after', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5020;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.ERROR;RR.INIT;Q.INIT;');
                    Observer.Expect('part.second.trace.before', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5020;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.ERROR;RR.INIT;Q.INIT;');
                    Observer.Expect('part.second.ok', 'Yes');
                    Observer.Expect('part.second.error.code', '');
                    Observer.Expect('part.second.error.text', '');
                    Observer.Expect('part.second.value', '1/0/0/');
                    Observer.Expect('part.second.trace.after', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5020;Q.AGR;Q.AGR;Q.AGCR;RR.HANDLER.ERROR;RR.INIT;Q.INIT;');
                    Observer.Expect('handler.initial.id', '5020');
                    Observer.Expect('handler.root', '1/1/opened/5020/host-first');
                    Observer.Expect('handler.trace', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5020;Q.AGR;Q.AGR;Q.AGCR;');
                    Observer.Expect('next.target.id', '5021');
                    Observer.Expect('next.returned', 'No');
                    Observer.Expect('next.reached.id', '-1');
                    Observer.Expect('inner.ok', 'No');
                    Observer.Expect('inner.error.code', '');
                    Observer.Expect('inner.error.text', '');
                    Observer.Expect('handler.before.return.phase', '');
                    Observer.Expect('handler.before.return.trace', '');
                    Observer.Expect('db.host.first', 'host-first');
                    Observer.Expect('db.host.second', 'host-second');
                    Observer.Expect('db.part.first', 'part-first');
                    Observer.Expect('db.part.second', 'part-second');
                    Observer.Expect('case', 'RR_HandlerDialog_Observe');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'RR_RowInvokeDirect_Observe':
                begin
                    Observer.Expect('prepared.root', '1/0/prepared/5030/host-first');
                    Observer.Expect('run.ok', 'No');
                    Observer.Expect('run.error.code', 'ClientPageAbort:FormAbort');
                    Observer.Expect('run.error.text', 'root row handler failure');
                    Observer.Expect('trace.after.run', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5030;Q.AGR;Q.AGR;Q.AGCR;RR.NEXT.ENTER;RR.AGCR.5031;RR.ROW.ERROR;');
                    Observer.Expect('root.trace.before', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5030;Q.AGR;Q.AGR;Q.AGCR;RR.NEXT.ENTER;RR.AGCR.5031;RR.ROW.ERROR;');
                    Observer.Expect('root.ok', 'Yes');
                    Observer.Expect('root.error.code', '');
                    Observer.Expect('root.error.text', '');
                    Observer.Expect('root.value', '1/0/initialized/0/');
                    Observer.Expect('root.trace.after', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5030;Q.AGR;Q.AGR;Q.AGCR;RR.NEXT.ENTER;RR.AGCR.5031;RR.ROW.ERROR;RR.INIT;');
                    Observer.Expect('part.first.trace.before', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5030;Q.AGR;Q.AGR;Q.AGCR;RR.NEXT.ENTER;RR.AGCR.5031;RR.ROW.ERROR;RR.INIT;');
                    Observer.Expect('part.first.ok', 'Yes');
                    Observer.Expect('part.first.error.code', '');
                    Observer.Expect('part.first.error.text', '');
                    Observer.Expect('part.first.value', '1/0/0/');
                    Observer.Expect('part.first.trace.after', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5030;Q.AGR;Q.AGR;Q.AGCR;RR.NEXT.ENTER;RR.AGCR.5031;RR.ROW.ERROR;RR.INIT;Q.INIT;');
                    Observer.Expect('part.second.trace.before', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5030;Q.AGR;Q.AGR;Q.AGCR;RR.NEXT.ENTER;RR.AGCR.5031;RR.ROW.ERROR;RR.INIT;Q.INIT;');
                    Observer.Expect('part.second.ok', 'Yes');
                    Observer.Expect('part.second.error.code', '');
                    Observer.Expect('part.second.error.text', '');
                    Observer.Expect('part.second.value', '1/0/0/');
                    Observer.Expect('part.second.trace.after', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5030;Q.AGR;Q.AGR;Q.AGCR;RR.NEXT.ENTER;RR.AGCR.5031;RR.ROW.ERROR;RR.INIT;Q.INIT;');
                    Observer.Expect('handler.initial.id', '5030');
                    Observer.Expect('handler.root', '1/1/opened/5030/host-first');
                    Observer.Expect('handler.trace', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5030;Q.AGR;Q.AGR;Q.AGCR;');
                    Observer.Expect('next.target.id', '5031');
                    Observer.Expect('next.returned', 'No');
                    Observer.Expect('next.reached.id', '-1');
                    Observer.Expect('inner.ok', 'No');
                    Observer.Expect('inner.error.code', '');
                    Observer.Expect('inner.error.text', '');
                    Observer.Expect('handler.before.return.phase', '');
                    Observer.Expect('handler.before.return.trace', '');
                    Observer.Expect('db.host.first', 'host-first');
                    Observer.Expect('db.host.second', 'host-second');
                    Observer.Expect('db.part.first', 'part-first');
                    Observer.Expect('db.part.second', 'part-second');
                    Observer.Expect('case', 'RR_RowInvokeDirect_Observe');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            'RR_RowInvokeTryCaught_Observe':
                begin
                    Observer.Expect('prepared.root', '1/0/prepared/5040/host-first');
                    Observer.Expect('run.ok', 'No');
                    Observer.Expect('run.error.code', 'ClientPageAbort:FormAbort');
                    Observer.Expect('run.error.text', 'root row handler failure');
                    Observer.Expect('trace.after.run', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5040;Q.AGR;Q.AGR;Q.AGCR;RR.TRY.NEXT.ENTER;RR.AGCR.5041;RR.ROW.ERROR;');
                    Observer.Expect('root.trace.before', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5040;Q.AGR;Q.AGR;Q.AGCR;RR.TRY.NEXT.ENTER;RR.AGCR.5041;RR.ROW.ERROR;');
                    Observer.Expect('root.ok', 'Yes');
                    Observer.Expect('root.error.code', '');
                    Observer.Expect('root.error.text', '');
                    Observer.Expect('root.value', '1/0/initialized/0/');
                    Observer.Expect('root.trace.after', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5040;Q.AGR;Q.AGR;Q.AGCR;RR.TRY.NEXT.ENTER;RR.AGCR.5041;RR.ROW.ERROR;RR.INIT;');
                    Observer.Expect('part.first.trace.before', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5040;Q.AGR;Q.AGR;Q.AGCR;RR.TRY.NEXT.ENTER;RR.AGCR.5041;RR.ROW.ERROR;RR.INIT;');
                    Observer.Expect('part.first.ok', 'Yes');
                    Observer.Expect('part.first.error.code', '');
                    Observer.Expect('part.first.error.text', '');
                    Observer.Expect('part.first.value', '1/0/0/');
                    Observer.Expect('part.first.trace.after', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5040;Q.AGR;Q.AGR;Q.AGCR;RR.TRY.NEXT.ENTER;RR.AGCR.5041;RR.ROW.ERROR;RR.INIT;Q.INIT;');
                    Observer.Expect('part.second.trace.before', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5040;Q.AGR;Q.AGR;Q.AGCR;RR.TRY.NEXT.ENTER;RR.AGCR.5041;RR.ROW.ERROR;RR.INIT;Q.INIT;');
                    Observer.Expect('part.second.ok', 'Yes');
                    Observer.Expect('part.second.error.code', '');
                    Observer.Expect('part.second.error.text', '');
                    Observer.Expect('part.second.value', '1/0/0/');
                    Observer.Expect('part.second.trace.after', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5040;Q.AGR;Q.AGR;Q.AGCR;RR.TRY.NEXT.ENTER;RR.AGCR.5041;RR.ROW.ERROR;RR.INIT;Q.INIT;');
                    Observer.Expect('handler.initial.id', '5040');
                    Observer.Expect('handler.root', '1/1/opened/5040/host-first');
                    Observer.Expect('handler.trace', 'RR.INIT;Q.INIT;RR.OPEN;Q.OPEN;RR.AGCR.5040;Q.AGR;Q.AGR;Q.AGCR;');
                    Observer.Expect('next.target.id', '5041');
                    Observer.Expect('next.returned', 'No');
                    Observer.Expect('next.reached.id', '-1');
                    Observer.Expect('inner.ok', 'No');
                    Observer.Expect('inner.error.code', '');
                    Observer.Expect('inner.error.text', '');
                    Observer.Expect('handler.before.return.phase', '');
                    Observer.Expect('handler.before.return.trace', '');
                    Observer.Expect('db.host.first', 'host-first');
                    Observer.Expect('db.host.second', 'host-second');
                    Observer.Expect('db.part.first', 'part-first');
                    Observer.Expect('db.part.second', 'part-second');
                    Observer.Expect('case', 'RR_RowInvokeTryCaught_Observe');
                    Observer.Expect('capture.end', 'COMPLETE');
                end;
            else Error('Unknown modal view contract: %1', Identity);
        end;
    end;
}
