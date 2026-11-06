// BC Documentation: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/testaction/testaction-data-type
// Scope: native observation bootstrap, not passing contracts. No action presence or event execution assumed.
// Fixtures: ALT Universal, ALTFixtureCleanup, Probe Observer, own definitions in EventOnlyObjects.al.
// Duplicate audit: LabelControlContracts covers no-subscriber empty actions; P114/PageActionSubscriberErrors require a source body or RunObject.
codeunit 69994 "PAG EventOnly Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var O: Codeunit "Probe Observer"; L: Codeunit "PAG EventOnly Log";
    local procedure Initialize()
    var Cleanup: Codeunit ALTFixtureCleanup; R: Record "ALT Universal"; Dep: Record "LT AO Dep Row";
    begin
        Cleanup.Initialize(); R."Entry No." := 1; R."Integer Field" := 5; R.Insert(false); Dep.Id := 1; Dep.Name := 'seed'; Dep.Insert(false); Commit();
        L.Reset(); O.Discard();
    end;
    local procedure Stored(Name: Text)
    var R: Record "ALT Universal";
    begin R.Get(1); O.Observe(Name, Format(R."Integer Field")); end;
    [TryFunction]
    local procedure ReadMetadata(Action: TestAction; var Visible: Boolean; var Enabled: Boolean; var Caption: Text)
    begin Visible := Action.Visible(); Enabled := Action.Enabled(); Caption := Action.Caption(); end;
    local procedure Metadata(Action: TestAction): Boolean
    var Ok: Boolean; Visible: Boolean; Enabled: Boolean; Caption: Text;
    begin
        Ok := ReadMetadata(Action, Visible, Enabled, Caption);
        O.Observe('metadata.ok', Format(Ok));
        if Ok then begin
            O.Observe('visible', Format(Visible)); O.Observe('enabled', Format(Enabled)); O.Observe('caption', Caption);
        end else O.ObserveError('metadata.error');
        exit(Ok);
    end;
    local procedure Invoke(Action: TestAction; Present: Boolean)
    begin
        if Present then begin Action.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror Action.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
    end;
    local procedure Finish(var P: TestPage "PAG EventOnly Page")
    begin
        O.Observe('displayed.after', P.Number.Value()); Stored('stored.after');
        O.Observe('trace.before.close', L.ReadTrace()); P.Close();
        Stored('stored.closed'); O.Observe('trace.closed', L.ReadTrace());
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
    procedure EventOnly_BaseAfter()
    var P: TestPage "PAG EventOnly Page"; Present: Boolean;
    begin
        Initialize(); O.Observe('case', 'EventOnly_BaseAfter');
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Present := Metadata(P.BaseAfter); Invoke(P.BaseAfter, Present);
        Finish(P);
    end;
    [Test]
    procedure EventOnly_BaseBoth()
    var P: TestPage "PAG EventOnly Page"; Present: Boolean;
    begin
        Initialize(); O.Observe('case', 'EventOnly_BaseBoth');
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Present := Metadata(P.BaseBoth); Invoke(P.BaseBoth, Present);
        Finish(P);
    end;
    local procedure StoredExtension(Name: Text)
    var R: Record "LT AO Dep Row";
    begin R.Get(1); O.Observe(Name, R.Name); end;
    local procedure FinishExtension(var P: TestPage "LT AO Dep Card")
    begin
        O.Observe('displayed.after', P.Name.Value()); StoredExtension('stored.after');
        O.Observe('trace.before.close', L.ReadTrace()); P.Close();
        StoredExtension('stored.closed'); O.Observe('trace.closed', L.ReadTrace());
        O.Observe('capture.end', 'COMPLETE'); O.Finish();
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
    procedure EventOnly_ExtensionAfter()
    var P: TestPage "LT AO Dep Card"; Present: Boolean;
    begin
        Initialize(); O.Observe('case', 'EventOnly_ExtensionAfter');
        P.OpenView(); O.Observe('displayed.open', P.Name.Value()); StoredExtension('stored.open');
        Present := Metadata(P.ExtensionAfter); Invoke(P.ExtensionAfter, Present);
        FinishExtension(P);
    end;
    [Test]
    procedure EventOnly_ExtensionBoth()
    var P: TestPage "LT AO Dep Card"; Present: Boolean;
    begin
        Initialize(); O.Observe('case', 'EventOnly_ExtensionBoth');
        P.OpenView(); O.Observe('displayed.open', P.Name.Value()); StoredExtension('stored.open');
        Present := Metadata(P.ExtensionBoth); Invoke(P.ExtensionBoth, Present);
        FinishExtension(P);
    end;
    [Test]
    procedure EventOnly_NoSubscriber()
    var P: TestPage "PAG EventOnly Page"; Present: Boolean;
    begin
        Initialize(); O.Observe('case', 'EventOnly_NoSubscriber');
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Present := Metadata(P.NoSubscriber); Invoke(P.NoSubscriber, Present);
        Finish(P);
    end;
    [Test]
    procedure EventOnly_NormalBody()
    var P: TestPage "PAG EventOnly Page"; Present: Boolean;
    begin
        Initialize(); O.Observe('case', 'EventOnly_NormalBody');
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Present := Metadata(P.Normal); Invoke(P.Normal, Present);
        Finish(P);
    end;
}
