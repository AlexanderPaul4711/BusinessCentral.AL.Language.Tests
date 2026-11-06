// BC Documentation: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/testaction/testaction-data-type
// Scope: Literal contracts from complete identical native 27.5/28.5/29 captures at 179466132faeffb0767d127d3d4f8f76746999be.
// TestAction is an implicit control API, not an AL parameter type. Use concrete TestPage targets.
// Fixtures: ALT Universal, LT AO Dep Row/Card from dependency app, Cleanup, Observer, EventOnlyObjects.al.
codeunit 69994 "PAG EventOnly Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var O: Codeunit "Probe Observer"; L: Codeunit "PAG EventOnly Log"; Identity: Text;
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
        O.Observe('capture.end', 'COMPLETE'); VerifyObserved(); O.Verify();
    end;
    local procedure FinishExtension(var P: TestPage "LT AO Dep Card" )
    begin
        O.Observe('displayed.after', P.Name.Value()); StoredExtension('stored.after');
        O.Observe('trace.before.close', L.ReadTrace()); P.Close();
        StoredExtension('stored.closed'); O.Observe('trace.closed', L.ReadTrace());
        O.Observe('capture.end', 'COMPLETE'); VerifyObserved(); O.Verify();
    end;
    [Test]
    procedure EventOnly_OpenWithoutInvoke()
    var P: TestPage "PAG EventOnly Page";
    begin
        Initialize(); Identity := 'EventOnly_OpenWithoutInvoke'; O.Observe('case', 'EventOnly_OpenWithoutInvoke');
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Finish(P);
    end;
    [Test]
    procedure EventOnly_ExtensionOpenWithoutInvoke()
    var P: TestPage "LT AO Dep Card";
    begin
        Initialize(); Identity := 'EventOnly_ExtensionOpenWithoutInvoke'; O.Observe('case', 'EventOnly_ExtensionOpenWithoutInvoke');
        P.OpenView(); O.Observe('displayed.open', P.Name.Value()); StoredExtension('stored.open');
        FinishExtension(P);
    end;
    [Test]
    procedure EventOnly_BaseAfter()
    var P: TestPage "PAG EventOnly Page"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_BaseAfter'; O.Observe('case', 'EventOnly_BaseAfter');
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
        Initialize(); Identity := 'EventOnly_BaseBoth'; O.Observe('case', 'EventOnly_BaseBoth');
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
        Initialize(); Identity := 'EventOnly_ExtensionAfter'; O.Observe('case', 'EventOnly_ExtensionAfter');
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
        Initialize(); Identity := 'EventOnly_ExtensionBoth'; O.Observe('case', 'EventOnly_ExtensionBoth');
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
        Initialize(); Identity := 'EventOnly_NoSubscriber'; O.Observe('case', 'EventOnly_NoSubscriber');
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
        Initialize(); Identity := 'EventOnly_NormalBody'; O.Observe('case', 'EventOnly_NormalBody');
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Ok := ReadBaseMetadata(P, 3, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        if Ok then begin P.Normal.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror P.Normal.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
        Finish(P);
    end;
    [Test]
    procedure EventOnly_BaseBeforeError()
    var P: TestPage "PAG EventOnly Page"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_BaseBeforeError'; O.Observe('case', 'EventOnly_BaseBeforeError'); L.FailAt('both.before');
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Ok := ReadBaseMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        asserterror P.BaseBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        Finish(P);
    end;
    [Test]
    procedure EventOnly_BaseAfterError()
    var P: TestPage "PAG EventOnly Page"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_BaseAfterError'; O.Observe('case', 'EventOnly_BaseAfterError'); L.FailAt('both.after');
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Ok := ReadBaseMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        asserterror P.BaseBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        Finish(P);
    end;
    [Test]
    procedure EventOnly_ExtensionBeforeError()
    var P: TestPage "LT AO Dep Card"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_ExtensionBeforeError'; O.Observe('case', 'EventOnly_ExtensionBeforeError'); L.FailAt('extension.both.before');
        P.OpenView(); O.Observe('displayed.open', P.Name.Value()); StoredExtension('stored.open');
        Ok := ReadExtensionMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        asserterror P.ExtensionBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        FinishExtension(P);
    end;
    [Test]
    procedure EventOnly_ExtensionAfterError()
    var P: TestPage "LT AO Dep Card"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_ExtensionAfterError'; O.Observe('case', 'EventOnly_ExtensionAfterError'); L.FailAt('extension.both.after');
        P.OpenView(); O.Observe('displayed.open', P.Name.Value()); StoredExtension('stored.open');
        Ok := ReadExtensionMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        asserterror P.ExtensionBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        FinishExtension(P);
    end;
    [TryFunction]
    local procedure ReadPartMetadata(var P: TestPage "PAG EventOnly Part Host"; var Visible: Boolean; var Enabled: Boolean)
    begin Visible := P.Lines.PartAfter.Visible(); Enabled := P.Lines.PartAfter.Enabled(); end;
    local procedure FinishPart(var P: TestPage "PAG EventOnly Part Host")
    begin
        O.Observe('displayed.after', P.Lines.Number.Value()); Stored('stored.after');
        O.Observe('trace.before.close', L.ReadTrace()); P.Close();
        Stored('stored.closed'); O.Observe('trace.closed', L.ReadTrace());
        O.Observe('capture.end', 'COMPLETE'); VerifyObserved(); O.Verify();
    end;
    [Test]
    procedure EventOnly_PartOpenWithoutInvoke()
    var P: TestPage "PAG EventOnly Part Host";
    begin
        Initialize(); Identity := 'EventOnly_PartOpenWithoutInvoke'; O.Observe('case', 'EventOnly_PartOpenWithoutInvoke');
        P.OpenView(); O.Observe('displayed.open', P.Lines.Number.Value()); Stored('stored.open');
        FinishPart(P);
    end;
    [Test]
    procedure EventOnly_PartAfter()
    var P: TestPage "PAG EventOnly Part Host"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_PartAfter'; O.Observe('case', 'EventOnly_PartAfter');
        P.OpenView(); O.Observe('displayed.open', P.Lines.Number.Value()); Stored('stored.open');
        Ok := ReadPartMetadata(P, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        if Ok then begin P.Lines.PartAfter.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror P.Lines.PartAfter.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
        FinishPart(P);
    end;

    [Test]
    procedure EventOnly_BaseEdit()
    var P: TestPage "PAG EventOnly Page"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_BaseEdit'; O.Observe('case', 'EventOnly_BaseEdit');
        P.OpenEdit(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Ok := ReadBaseMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        if Ok then begin P.BaseBoth.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror P.BaseBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
        Finish(P);
    end;

    [Test]
    procedure EventOnly_ExtensionEdit()
    var P: TestPage "LT AO Dep Card"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_ExtensionEdit'; O.Observe('case', 'EventOnly_ExtensionEdit');
        P.OpenEdit(); O.Observe('displayed.open', P.Name.Value()); StoredExtension('stored.open');
        Ok := ReadExtensionMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        if Ok then begin P.ExtensionBoth.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror P.ExtensionBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
        FinishExtension(P);
    end;

    [Test]
    procedure EventOnly_BaseDirtyEdit()
    var P: TestPage "PAG EventOnly Page"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_BaseDirtyEdit'; O.Observe('case', 'EventOnly_BaseDirtyEdit');
        P.OpenEdit(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        P.Number.SetValue(11); O.Observe('displayed.dirty', P.Number.Value()); Stored('stored.dirty');
        Ok := ReadBaseMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        if Ok then begin P.BaseBoth.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror P.BaseBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
        Finish(P);
    end;

    [Test]
    procedure EventOnly_PartEdit()
    var P: TestPage "PAG EventOnly Part Host"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_PartEdit'; O.Observe('case', 'EventOnly_PartEdit');
        P.OpenEdit(); O.Observe('displayed.open', P.Lines.Number.Value()); Stored('stored.open');
        Ok := ReadPartMetadata(P, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        if Ok then begin P.Lines.PartAfter.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror P.Lines.PartAfter.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
        FinishPart(P);
    end;

    [Test]
    procedure EventOnly_PartDirtyEdit()
    var P: TestPage "PAG EventOnly Part Host"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_PartDirtyEdit'; O.Observe('case', 'EventOnly_PartDirtyEdit');
        P.OpenEdit(); O.Observe('displayed.open', P.Lines.Number.Value()); Stored('stored.open');
        P.Lines.Number.SetValue(11); O.Observe('displayed.dirty', P.Lines.Number.Value()); Stored('stored.dirty');
        Ok := ReadPartMetadata(P, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        if Ok then begin P.Lines.PartAfter.Invoke(); O.Observe('invoke', 'RETURNED'); end else begin
            asserterror P.Lines.PartAfter.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        end;
        FinishPart(P);
    end;

    local procedure VerifyObserved()
    begin
        case Identity of
            'EventOnly_BaseAfter':
                begin
                    O.Expect('case', 'EventOnly_BaseAfter');
                    O.Expect('displayed.open', '5');
                    O.Expect('stored.open', '5');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'RETURNED');
                    O.Expect('displayed.after', '5');
                    O.Expect('stored.after', '5');
                    O.Expect('trace.before.close', 'open;base.after:1:5;');
                    O.Expect('stored.closed', '5');
                    O.Expect('trace.closed', 'open;base.after:1:5;close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_BaseAfterError':
                begin
                    O.Expect('case', 'EventOnly_BaseAfterError');
                    O.Expect('displayed.open', '5');
                    O.Expect('stored.open', '5');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'REFUSED');
                    O.Expect('invoke.error|text', 'event-only subscriber failure: both.after');
                    O.Expect('invoke.error|code', 'TestWrapped:Dialog');
                    O.Expect('displayed.after', '5');
                    O.Expect('stored.after', '5');
                    O.Expect('trace.before.close', 'open;both.before:1:5;both.after:1:8;');
                    O.Expect('stored.closed', '5');
                    O.Expect('trace.closed', 'open;both.before:1:5;both.after:1:8;close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_BaseBeforeError':
                begin
                    O.Expect('case', 'EventOnly_BaseBeforeError');
                    O.Expect('displayed.open', '5');
                    O.Expect('stored.open', '5');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'REFUSED');
                    O.Expect('invoke.error|text', 'event-only subscriber failure: both.before');
                    O.Expect('invoke.error|code', 'TestWrapped:Dialog');
                    O.Expect('displayed.after', '5');
                    O.Expect('stored.after', '5');
                    O.Expect('trace.before.close', 'open;both.before:1:5;');
                    O.Expect('stored.closed', '5');
                    O.Expect('trace.closed', 'open;both.before:1:5;close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_BaseBoth':
                begin
                    O.Expect('case', 'EventOnly_BaseBoth');
                    O.Expect('displayed.open', '5');
                    O.Expect('stored.open', '5');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'RETURNED');
                    O.Expect('displayed.after', '5');
                    O.Expect('stored.after', '5');
                    O.Expect('trace.before.close', 'open;both.before:1:5;both.after:1:8;');
                    O.Expect('stored.closed', '5');
                    O.Expect('trace.closed', 'open;both.before:1:5;both.after:1:8;close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_BaseDirtyEdit':
                begin
                    O.Expect('case', 'EventOnly_BaseDirtyEdit');
                    O.Expect('displayed.open', '5');
                    O.Expect('stored.open', '5');
                    O.Expect('displayed.dirty', '11');
                    O.Expect('stored.dirty', '5');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'RETURNED');
                    O.Expect('displayed.after', '21');
                    O.Expect('stored.after', '21');
                    O.Expect('trace.before.close', 'open;both.before:1:11;both.after:1:14;');
                    O.Expect('stored.closed', '21');
                    O.Expect('trace.closed', 'open;both.before:1:11;both.after:1:14;close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_BaseEdit':
                begin
                    O.Expect('case', 'EventOnly_BaseEdit');
                    O.Expect('displayed.open', '5');
                    O.Expect('stored.open', '5');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'RETURNED');
                    O.Expect('displayed.after', '15');
                    O.Expect('stored.after', '15');
                    O.Expect('trace.before.close', 'open;both.before:1:5;both.after:1:8;');
                    O.Expect('stored.closed', '15');
                    O.Expect('trace.closed', 'open;both.before:1:5;both.after:1:8;close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_ExtensionAfter':
                begin
                    O.Expect('case', 'EventOnly_ExtensionAfter');
                    O.Expect('displayed.open', 'seed');
                    O.Expect('stored.open', 'seed');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'RETURNED');
                    O.Expect('displayed.after', 'seed');
                    O.Expect('stored.after', 'seed');
                    O.Expect('trace.before.close', 'extension.after:1:seed;');
                    O.Expect('stored.closed', 'seed');
                    O.Expect('trace.closed', 'extension.after:1:seed;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_ExtensionAfterError':
                begin
                    O.Expect('case', 'EventOnly_ExtensionAfterError');
                    O.Expect('displayed.open', 'seed');
                    O.Expect('stored.open', 'seed');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'REFUSED');
                    O.Expect('invoke.error|text', 'event-only subscriber failure: extension.both.after');
                    O.Expect('invoke.error|code', 'TestWrapped:Dialog');
                    O.Expect('displayed.after', 'seed');
                    O.Expect('stored.after', 'seed');
                    O.Expect('trace.before.close', 'extension.both.before:1:seed;extension.both.after:1:seed-B;');
                    O.Expect('stored.closed', 'seed');
                    O.Expect('trace.closed', 'extension.both.before:1:seed;extension.both.after:1:seed-B;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_ExtensionBeforeError':
                begin
                    O.Expect('case', 'EventOnly_ExtensionBeforeError');
                    O.Expect('displayed.open', 'seed');
                    O.Expect('stored.open', 'seed');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'REFUSED');
                    O.Expect('invoke.error|text', 'event-only subscriber failure: extension.both.before');
                    O.Expect('invoke.error|code', 'TestWrapped:Dialog');
                    O.Expect('displayed.after', 'seed');
                    O.Expect('stored.after', 'seed');
                    O.Expect('trace.before.close', 'extension.both.before:1:seed;');
                    O.Expect('stored.closed', 'seed');
                    O.Expect('trace.closed', 'extension.both.before:1:seed;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_ExtensionBoth':
                begin
                    O.Expect('case', 'EventOnly_ExtensionBoth');
                    O.Expect('displayed.open', 'seed');
                    O.Expect('stored.open', 'seed');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'RETURNED');
                    O.Expect('displayed.after', 'seed');
                    O.Expect('stored.after', 'seed');
                    O.Expect('trace.before.close', 'extension.both.before:1:seed;extension.both.after:1:seed-B;');
                    O.Expect('stored.closed', 'seed');
                    O.Expect('trace.closed', 'extension.both.before:1:seed;extension.both.after:1:seed-B;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_ExtensionEdit':
                begin
                    O.Expect('case', 'EventOnly_ExtensionEdit');
                    O.Expect('displayed.open', 'seed');
                    O.Expect('stored.open', 'seed');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'RETURNED');
                    O.Expect('displayed.after', 'seed-B-A');
                    O.Expect('stored.after', 'seed-B-A');
                    O.Expect('trace.before.close', 'extension.both.before:1:seed;extension.both.after:1:seed-B;');
                    O.Expect('stored.closed', 'seed-B-A');
                    O.Expect('trace.closed', 'extension.both.before:1:seed;extension.both.after:1:seed-B;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_ExtensionOpenWithoutInvoke':
                begin
                    O.Expect('case', 'EventOnly_ExtensionOpenWithoutInvoke');
                    O.Expect('displayed.open', 'seed');
                    O.Expect('stored.open', 'seed');
                    O.Expect('displayed.after', 'seed');
                    O.Expect('stored.after', 'seed');
                    O.Expect('trace.before.close', '');
                    O.Expect('stored.closed', 'seed');
                    O.Expect('trace.closed', '');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_NoSubscriber':
                begin
                    O.Expect('case', 'EventOnly_NoSubscriber');
                    O.Expect('displayed.open', '5');
                    O.Expect('stored.open', '5');
                    O.Expect('metadata.ok', 'No');
                    O.Expect('metadata.error|text', 'The action with ID = n is not found on the page.');
                    O.Expect('metadata.error|code', 'TestActionNotFound');
                    O.Expect('invoke', 'REFUSED');
                    O.Expect('invoke.error|text', 'The action with ID = n is not found on the page.');
                    O.Expect('invoke.error|code', 'TestActionNotFound');
                    O.Expect('displayed.after', '5');
                    O.Expect('stored.after', '5');
                    O.Expect('trace.before.close', 'open;');
                    O.Expect('stored.closed', '5');
                    O.Expect('trace.closed', 'open;close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_NormalBody':
                begin
                    O.Expect('case', 'EventOnly_NormalBody');
                    O.Expect('displayed.open', '5');
                    O.Expect('stored.open', '5');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'RETURNED');
                    O.Expect('displayed.after', '5');
                    O.Expect('stored.after', '5');
                    O.Expect('trace.before.close', 'open;normal.before:1:5;normal.body:8;normal.after:1:19;');
                    O.Expect('stored.closed', '5');
                    O.Expect('trace.closed', 'open;normal.before:1:5;normal.body:8;normal.after:1:19;close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_OpenWithoutInvoke':
                begin
                    O.Expect('case', 'EventOnly_OpenWithoutInvoke');
                    O.Expect('displayed.open', '5');
                    O.Expect('stored.open', '5');
                    O.Expect('displayed.after', '5');
                    O.Expect('stored.after', '5');
                    O.Expect('trace.before.close', 'open;');
                    O.Expect('stored.closed', '5');
                    O.Expect('trace.closed', 'open;close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_PartAfter':
                begin
                    O.Expect('case', 'EventOnly_PartAfter');
                    O.Expect('displayed.open', '5');
                    O.Expect('stored.open', '5');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'RETURNED');
                    O.Expect('displayed.after', '5');
                    O.Expect('stored.after', '5');
                    O.Expect('trace.before.close', 'part.after:1:5;');
                    O.Expect('stored.closed', '5');
                    O.Expect('trace.closed', 'part.after:1:5;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_PartDirtyEdit':
                begin
                    O.Expect('case', 'EventOnly_PartDirtyEdit');
                    O.Expect('displayed.open', '5');
                    O.Expect('stored.open', '5');
                    O.Expect('displayed.dirty', '11');
                    O.Expect('stored.dirty', '5');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'RETURNED');
                    O.Expect('displayed.after', '18');
                    O.Expect('stored.after', '18');
                    O.Expect('trace.before.close', 'part.after:1:11;');
                    O.Expect('stored.closed', '18');
                    O.Expect('trace.closed', 'part.after:1:11;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_PartEdit':
                begin
                    O.Expect('case', 'EventOnly_PartEdit');
                    O.Expect('displayed.open', '5');
                    O.Expect('stored.open', '5');
                    O.Expect('metadata.ok', 'Yes');
                    O.Expect('visible', 'Yes');
                    O.Expect('enabled', 'Yes');
                    O.Expect('invoke', 'RETURNED');
                    O.Expect('displayed.after', '12');
                    O.Expect('stored.after', '12');
                    O.Expect('trace.before.close', 'part.after:1:5;');
                    O.Expect('stored.closed', '12');
                    O.Expect('trace.closed', 'part.after:1:5;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'EventOnly_PartOpenWithoutInvoke':
                begin
                    O.Expect('case', 'EventOnly_PartOpenWithoutInvoke');
                    O.Expect('displayed.open', '5');
                    O.Expect('stored.open', '5');
                    O.Expect('displayed.after', '5');
                    O.Expect('stored.after', '5');
                    O.Expect('trace.before.close', '');
                    O.Expect('stored.closed', '5');
                    O.Expect('trace.closed', '');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            else Error('Unknown event-only observation: %1', Identity);
        end;
    end;

    local procedure FinishErrorObservation(var P: TestPage "PAG EventOnly Page" )
    begin
        O.Observe('displayed.after', P.Number.Value()); Stored('stored.after');
        O.Observe('trace.before.close', L.ReadTrace()); P.Close();
        Stored('stored.closed'); O.Observe('trace.closed', L.ReadTrace());
        O.Observe('capture.end', 'COMPLETE'); O.Finish();
    end;

    local procedure FinishExtensionErrorObservation(var P: TestPage "LT AO Dep Card" )
    begin
        O.Observe('displayed.after', P.Name.Value()); StoredExtension('stored.after');
        O.Observe('trace.before.close', L.ReadTrace()); P.Close();
        StoredExtension('stored.closed'); O.Observe('trace.closed', L.ReadTrace());
        O.Observe('capture.end', 'COMPLETE'); O.Finish();
    end;

    [Test]
    procedure EventOnly_BaseEditBeforeError()
    var P: TestPage "PAG EventOnly Page"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_BaseEditBeforeError'; O.Observe('case', 'EventOnly_BaseEditBeforeError'); L.FailAt('both.before');
        P.OpenEdit(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Ok := ReadBaseMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        asserterror P.BaseBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        FinishErrorObservation(P);
    end;

    [Test]
    procedure EventOnly_BaseEditAfterError()
    var P: TestPage "PAG EventOnly Page"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_BaseEditAfterError'; O.Observe('case', 'EventOnly_BaseEditAfterError'); L.FailAt('both.after');
        P.OpenEdit(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Ok := ReadBaseMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        asserterror P.BaseBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        FinishErrorObservation(P);
    end;

    [Test]
    procedure EventOnly_ExtensionEditBeforeError()
    var P: TestPage "LT AO Dep Card"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_ExtensionEditBeforeError'; O.Observe('case', 'EventOnly_ExtensionEditBeforeError'); L.FailAt('extension.both.before');
        P.OpenEdit(); O.Observe('displayed.open', P.Name.Value()); StoredExtension('stored.open');
        Ok := ReadExtensionMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        asserterror P.ExtensionBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        FinishExtensionErrorObservation(P);
    end;

    [Test]
    procedure EventOnly_ExtensionEditAfterError()
    var P: TestPage "LT AO Dep Card"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_ExtensionEditAfterError'; O.Observe('case', 'EventOnly_ExtensionEditAfterError'); L.FailAt('extension.both.after');
        P.OpenEdit(); O.Observe('displayed.open', P.Name.Value()); StoredExtension('stored.open');
        Ok := ReadExtensionMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        asserterror P.ExtensionBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        FinishExtensionErrorObservation(P);
    end;

    [Test]
    procedure EventOnly_ViewWriteAfterError()
    var P: TestPage "PAG EventOnly Page"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_ViewWriteAfterError'; O.Observe('case', 'EventOnly_ViewWriteAfterError'); L.FailAt('both.after'); L.RequestWrite('both.before', false);
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Ok := ReadBaseMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        asserterror P.BaseBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        FinishErrorObservation(P);
    end;

    [Test]
    procedure EventOnly_ViewCommitAfterError()
    var P: TestPage "PAG EventOnly Page"; Ok: Boolean; Visible: Boolean; Enabled: Boolean;
    begin
        Initialize(); Identity := 'EventOnly_ViewCommitAfterError'; O.Observe('case', 'EventOnly_ViewCommitAfterError'); L.FailAt('both.after'); L.RequestWrite('both.before', true);
        P.OpenView(); O.Observe('displayed.open', P.Number.Value()); Stored('stored.open');
        Ok := ReadBaseMetadata(P, 1, Visible, Enabled); Metadata(Ok, Visible, Enabled);
        asserterror P.BaseBoth.Invoke(); O.Observe('invoke', 'REFUSED'); O.ObserveError('invoke.error');
        FinishErrorObservation(P);
    end;
}
