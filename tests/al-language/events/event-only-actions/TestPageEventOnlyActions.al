// BC Documentation: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/testaction/testaction-data-type
// Scope: native observation bootstrap, not passing contracts. No action presence or event execution assumed.
// TestAction is an implicit control API, not an AL parameter type. Use concrete TestPage targets.
// Fixtures: ALT Universal, LT AO Dep Row/Card from dependency app, Cleanup, Observer, EventOnlyObjects.al.
codeunit 69994 "PAG EventOnly Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var O: Codeunit "Probe Observer"; L: Codeunit "PAG EventOnly Log";
    local procedure Initialize()
    var Cleanup: Codeunit ALTFixtureCleanup; R: Record "ALT Universal"; Dep: Record "LT AO Dep Row";
    begin
        Cleanup.Initialize(); R."Entry No." := 1; R."Integer Field" := 5; R.Insert(false);
        Dep.Id := 1; Dep.Name := 'seed'; Dep.Insert(false); Commit(); L.Reset(); O.Discard();
    end;
    local procedure Stored(Name: Text)
    var R: Record "ALT Universal";
    begin R.Get(1); O.Observe(Name, Format(R."Integer Field")); end;
    local procedure StoredExtension(Name: Text)
    var R: Record "LT AO Dep Row";
    begin R.Get(1); O.Observe(Name, R.Name); end;
    local procedure Metadata(Ok: Boolean; Visible: Boolean; Enabled: Boolean)
    begin
        O.Observe('metadata.ok', Format(Ok));
        if Ok then begin O.Observe('visible', Format(Visible)); O.Observe('enabled', Format(Enabled)); end
        else O.ObserveError('metadata.error');
    end;
    [TryFunction]
    local procedure ReadBaseMetadata(var P: TestPage "PAG EventOnly Page"; Choice: Integer; var Visible: Boolean; var Enabled: Boolean)
    begin
        case Choice of
            0: begin Visible := P.BaseAfter.Visible(); Enabled := P.BaseAfter.Enabled(); end;
            1: begin Visible := P.BaseBoth.Visible(); Enabled := P.BaseBoth.Enabled(); end;
            2: begin Visible := P.NoSubscriber.Visible(); Enabled := P.NoSubscriber.Enabled(); end;
            3: begin Visible := P.Normal.Visible(); Enabled := P.Normal.Enabled(); end;
            else Error('Unknown action metadata choice');
        end;
    end;
    [TryFunction]
    local procedure ReadExtensionMetadata(var P: TestPage "LT AO Dep Card"; Choice: Integer; var Visible: Boolean; var Enabled: Boolean)
    begin
        case Choice of
            0: begin Visible := P.ExtensionAfter.Visible(); Enabled := P.ExtensionAfter.Enabled(); end;
            1: begin Visible := P.ExtensionBoth.Visible(); Enabled := P.ExtensionBoth.Enabled(); end;
            else Error('Unknown action metadata choice');
        end;
    end;
    local procedure Finish(var P: TestPage "PAG EventOnly Page" )
    begin
        O.Observe('displayed.after', P.Number.Value()); Stored('stored.after');
        O.Observe('trace.before.close', L.ReadTrace()); P.Close();
        Stored('stored.closed'); O.Observe('trace.closed', L.ReadTrace());
        O.Observe('capture.end', 'COMPLETE'); O.Finish();
    end;
    local procedure FinishExtension(var P: TestPage "LT AO Dep Card" )
    begin
        O.Observe('displayed.after', P.Name.Value()); StoredExtension('stored.after');
        O.Observe('trace.before.close', L.ReadTrace()); P.Close();
        StoredExtension('stored.closed'); O.Observe('trace.closed', L.ReadTrace());
        O.Observe('capture.end', 'COMPLETE'); O.Finish();
    end;
    [Test]
    procedure EventOnly_OpenWithoutInvoke()
    var P: TestPage "PAG EventOnly Page";
    begin
        Initialize(); O.Observe('case', 'EventOnly_OpenWithoutInvoke');
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Finish(P);
    end;
    [Test]
    procedure EventOnly_ExtensionOpenWithoutInvoke()
    var P: TestPage "LT AO Dep Card";
    begin
        Initialize(); O.Observe('case', 'EventOnly_ExtensionOpenWithoutInvoke');
        P.OpenView(); O.Observe('displayed.open', P.Name.Value()); StoredExtension('stored.open');
        FinishExtension(P);
    end;
    [Test]
    procedure EventOnly_BaseAfter()
    var P: TestPage "PAG EventOnly Page"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); O.Observe('case', 'EventOnly_BaseAfter');
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Ok := ReadBaseMetadata(P, 0, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        if Ok then begin P.BaseAfter.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror P.BaseAfter.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
        Finish(P);
    end;
    [Test]
    procedure EventOnly_BaseBoth()
    var P: TestPage "PAG EventOnly Page"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); O.Observe('case', 'EventOnly_BaseBoth');
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Ok := ReadBaseMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        if Ok then begin P.BaseBoth.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror P.BaseBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
        Finish(P);
    end;
    [Test]
    procedure EventOnly_ExtensionAfter()
    var P: TestPage "LT AO Dep Card"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); O.Observe('case', 'EventOnly_ExtensionAfter');
        P.OpenView(); O.Observe('displayed.open', P.Name.Value()); StoredExtension('stored.open');
        Ok := ReadExtensionMetadata(P, 0, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        if Ok then begin P.ExtensionAfter.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror P.ExtensionAfter.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
        FinishExtension(P);
    end;
    [Test]
    procedure EventOnly_ExtensionBoth()
    var P: TestPage "LT AO Dep Card"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); O.Observe('case', 'EventOnly_ExtensionBoth');
        P.OpenView(); O.Observe('displayed.open', P.Name.Value()); StoredExtension('stored.open');
        Ok := ReadExtensionMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        if Ok then begin P.ExtensionBoth.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror P.ExtensionBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
        FinishExtension(P);
    end;
    [Test]
    procedure EventOnly_NoSubscriber()
    var P: TestPage "PAG EventOnly Page"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); O.Observe('case', 'EventOnly_NoSubscriber');
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Ok := ReadBaseMetadata(P, 2, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        if Ok then begin P.NoSubscriber.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror P.NoSubscriber.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
        Finish(P);
    end;
    [Test]
    procedure EventOnly_NormalBody()
    var P: TestPage "PAG EventOnly Page"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); O.Observe('case', 'EventOnly_NormalBody');
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Ok := ReadBaseMetadata(P, 3, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        if Ok then begin P.Normal.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror P.Normal.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
        Finish(P);
    end;
}
