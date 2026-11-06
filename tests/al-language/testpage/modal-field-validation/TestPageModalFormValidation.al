// BC Documentation: https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/page/page-runmodal-method
// Scope: measured ListPlus modal validation/save/close contracts; identical native27.5/28.5/29 captures at source5d9e46e6.
// Close-inside-handler cases separately observe the late RunModal failure and post-Asserterror rollback; not browser Cancel rollback.
// Fixtures: own validation/close definitions in ModalFormObjects.al; Probe Observer; ALTFixtureCleanup.
// Duplicate audit: TestPageClosingActions covers close actions but not ListPlus dirty-field/store/trigger effects;
// TestPageSaveDataLayer covers explicit Card saves, not suspended ListPlus modal validation and Cancel.
codeunit 69991 "PAG Modal Form Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var O: Codeunit "Probe Observer"; L: Codeunit "PAG Modal Form Log";
        Mode: Integer; Ending: Integer; Identity: Text;
    local procedure Initialize()
    var Cleanup: Codeunit ALTFixtureCleanup; R: Record "PAG Modal Form Row";
    begin
        Cleanup.Initialize();
        R.Id := 1; R.Value := 'seed'; R.Note := 'main-seed'; R.Insert(false);
        R.Id := 2; R.Value := 'side-seed'; R.Note := 'side-note'; R.Insert(false);
        Commit();
        L.Configure(0); O.Discard();
    end;
    local procedure Stored(Prefix: Text)
    var R: Record "PAG Modal Form Row";
    begin
        R.Get(1); O.Observe(Prefix + '.main', R.Value);
        R.Get(2); O.Observe(Prefix + '.side', R.Note);
    end;
    local procedure Measure(Name: Text; NewMode: Integer; Lookup: Boolean; EndingAction: Integer)
    var Pg: Page "PAG Modal Form ListPlus"; R: Record "PAG Modal Form Row"; Answer: Action;
    begin
        Identity := Name; Mode := NewMode; Ending := EndingAction; L.Configure(Mode);
        R.Get(1); Pg.SetRecord(R); Pg.LookupMode(Lookup);
        O.Observe('case', Identity);
        if Ending in [2, 3] then begin
            asserterror Answer := Pg.RunModal();
            O.ObserveError('runmodal.error');
            O.Observe('result', 'NO_RETURN_AFTER_HANDLER_CLOSE');
        end else begin
            Answer := Pg.RunModal();
            O.Observe('result', Format(Answer));
        end;
        if Ending in [2, 3] then Stored('postcatch') else Stored('returned');
        O.Observe('trace', L.ReadTrace()); O.Observe('capture.end', 'COMPLETE');
        VerifyObserved();
        O.Verify();
    end;
    [ModalPageHandler]
    procedure FormHandler(var P: TestPage "PAG Modal Form ListPlus")
    begin
        Stored('before');
        if Mode in [4, 5] then begin
            asserterror P.Value.SetValue('EDIT');
            O.ObserveError('validate.error');
        end else P.Value.SetValue('EDIT');
        O.Observe('displayed', P.Value.Value());
        Stored('validated');
        if Ending = 2 then begin
            asserterror P.Cancel().Invoke();
            O.ObserveError('cancel.error');
            O.Observe('after.refused.cancel', P.Value.Value());
            P.Close();
            Stored('closed.inside'); O.Observe('trace.closed.inside', L.ReadTrace());
        end else begin
            if Ending = 1 then P.Cancel().Invoke() else
                if Ending = 3 then begin
                    P.Close();
                    Stored('closed.inside'); O.Observe('trace.closed.inside', L.ReadTrace());
                end else P.OK().Invoke();
            if Mode = 2 then begin
                Stored('after.action'); O.Observe('trace.after.action', L.ReadTrace());
            end;
            if Mode = 3 then begin
                O.Observe('after.veto', P.Value.Value()); Stored('vetoed');
                L.AllowClose(); P.OK().Invoke();
            end;
        end;
    end;
    [Test]
    [HandlerFunctions('FormHandler')]
    procedure ListPlus_Validate_ThenOK()
    begin
        Initialize();
        Measure('ListPlus_Validate_ThenOK', 0, false, 0);
    end;
    [Test]
    [HandlerFunctions('FormHandler')]
    procedure ListPlus_Validate_ThenClose()
    begin
        Initialize();
        Measure('ListPlus_Validate_ThenClose', 0, false, 3);
    end;
    [Test]
    [HandlerFunctions('FormHandler')]
    procedure ListPlus_PlainCancel_RefusedThenClose()
    begin
        Initialize();
        Measure('ListPlus_PlainCancel_RefusedThenClose', 0, false, 2);
    end;
    [Test]
    [HandlerFunctions('FormHandler')]
    procedure ListPlus_LookupValidate_ThenOK()
    begin
        Initialize();
        Measure('ListPlus_LookupValidate_ThenOK', 0, true, 0);
    end;
    [Test]
    [HandlerFunctions('FormHandler')]
    procedure ListPlus_LookupValidate_ThenCancel()
    begin
        Initialize();
        Measure('ListPlus_LookupValidate_ThenCancel', 0, true, 1);
    end;
    [Test]
    [HandlerFunctions('FormHandler')]
    procedure ListPlus_ValidateOwnSave_ThenCancel()
    begin
        Initialize();
        Measure('ListPlus_ValidateOwnSave_ThenCancel', 1, true, 1);
    end;
    [Test]
    [HandlerFunctions('FormHandler')]
    procedure ListPlus_SaveVeto_ThenOK()
    begin
        Initialize();
        Measure('ListPlus_SaveVeto_ThenOK', 2, false, 0);
    end;
    [Test]
    [HandlerFunctions('FormHandler')]
    procedure ListPlus_CloseVeto_ThenSecondOK()
    begin
        Initialize();
        Measure('ListPlus_CloseVeto_ThenSecondOK', 3, false, 0);
    end;
    [Test]
    [HandlerFunctions('FormHandler')]
    procedure ListPlus_ValidateError_ThenCancel()
    begin
        Initialize();
        Measure('ListPlus_ValidateError_ThenCancel', 4, true, 1);
    end;
    [Test]
    [HandlerFunctions('FormHandler')]
    procedure ListPlus_ValidateCommitError_ThenCancel()
    begin
        Initialize();
        Measure('ListPlus_ValidateCommitError_ThenCancel', 5, true, 1);
    end;
    local procedure VerifyObserved()
    begin
        case Identity of
            'ListPlus_Validate_ThenOK':
                begin
                    O.Expect('case', 'ListPlus_Validate_ThenOK');
                    O.Expect('before.main', 'seed');
                    O.Expect('before.side', 'side-note');
                    O.Expect('displayed', 'EDIT');
                    O.Expect('validated.main', 'seed');
                    O.Expect('validated.side', 'side-EDIT');
                    O.Expect('result', 'OK');
                    O.Expect('returned.main', 'EDIT');
                    O.Expect('returned.side', 'side-EDIT');
                    O.Expect('trace', 'table.validate:EDIT;page.validate:EDIT;page.modify:EDIT;table.modify:1:EDIT;page.query:OK;page.close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'ListPlus_Validate_ThenClose':
                begin
                    O.Expect('case', 'ListPlus_Validate_ThenClose');
                    O.Expect('before.main', 'seed');
                    O.Expect('before.side', 'side-note');
                    O.Expect('displayed', 'EDIT');
                    O.Expect('validated.main', 'seed');
                    O.Expect('validated.side', 'side-EDIT');
                    O.Expect('closed.inside.main', 'EDIT');
                    O.Expect('closed.inside.side', 'side-EDIT');
                    O.Expect('trace.closed.inside', 'table.validate:EDIT;page.validate:EDIT;page.modify:EDIT;table.modify:1:EDIT;page.query:OK;page.close;');
                    O.Expect('runmodal.error|text', 'The RunModal procedure could not close the page 69990 as it has already been closed.');
                    O.Expect('runmodal.error|code', 'TestCodeUnit');
                    O.Expect('result', 'NO_RETURN_AFTER_HANDLER_CLOSE');
                    O.Expect('postcatch.main', 'seed');
                    O.Expect('postcatch.side', 'side-note');
                    O.Expect('trace', 'table.validate:EDIT;page.validate:EDIT;page.modify:EDIT;table.modify:1:EDIT;page.query:OK;page.close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'ListPlus_PlainCancel_RefusedThenClose':
                begin
                    O.Expect('case', 'ListPlus_PlainCancel_RefusedThenClose');
                    O.Expect('before.main', 'seed');
                    O.Expect('before.side', 'side-note');
                    O.Expect('displayed', 'EDIT');
                    O.Expect('validated.main', 'seed');
                    O.Expect('validated.side', 'side-EDIT');
                    O.Expect('cancel.error|text', 'The built-in action = Cancel is not found on the page.');
                    O.Expect('cancel.error|code', 'TestActionNotFound');
                    O.Expect('after.refused.cancel', 'EDIT');
                    O.Expect('closed.inside.main', 'EDIT');
                    O.Expect('closed.inside.side', 'side-note');
                    O.Expect('trace.closed.inside', 'table.validate:EDIT;page.validate:EDIT;page.modify:EDIT;table.modify:1:EDIT;page.query:OK;page.close;');
                    O.Expect('runmodal.error|text', 'The RunModal procedure could not close the page 69990 as it has already been closed.');
                    O.Expect('runmodal.error|code', 'TestCodeUnit');
                    O.Expect('result', 'NO_RETURN_AFTER_HANDLER_CLOSE');
                    O.Expect('postcatch.main', 'seed');
                    O.Expect('postcatch.side', 'side-note');
                    O.Expect('trace', 'table.validate:EDIT;page.validate:EDIT;page.modify:EDIT;table.modify:1:EDIT;page.query:OK;page.close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'ListPlus_LookupValidate_ThenOK':
                begin
                    O.Expect('case', 'ListPlus_LookupValidate_ThenOK');
                    O.Expect('before.main', 'seed');
                    O.Expect('before.side', 'side-note');
                    O.Expect('displayed', 'EDIT');
                    O.Expect('validated.main', 'seed');
                    O.Expect('validated.side', 'side-EDIT');
                    O.Expect('result', 'LookupOK');
                    O.Expect('returned.main', 'EDIT');
                    O.Expect('returned.side', 'side-EDIT');
                    O.Expect('trace', 'table.validate:EDIT;page.validate:EDIT;page.modify:EDIT;table.modify:1:EDIT;page.query:LookupOK;page.close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'ListPlus_LookupValidate_ThenCancel':
                begin
                    O.Expect('case', 'ListPlus_LookupValidate_ThenCancel');
                    O.Expect('before.main', 'seed');
                    O.Expect('before.side', 'side-note');
                    O.Expect('displayed', 'EDIT');
                    O.Expect('validated.main', 'seed');
                    O.Expect('validated.side', 'side-EDIT');
                    O.Expect('result', 'LookupCancel');
                    O.Expect('returned.main', 'EDIT');
                    O.Expect('returned.side', 'side-EDIT');
                    O.Expect('trace', 'table.validate:EDIT;page.validate:EDIT;page.modify:EDIT;table.modify:1:EDIT;page.query:LookupCancel;page.close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'ListPlus_ValidateOwnSave_ThenCancel':
                begin
                    O.Expect('case', 'ListPlus_ValidateOwnSave_ThenCancel');
                    O.Expect('before.main', 'seed');
                    O.Expect('before.side', 'side-note');
                    O.Expect('displayed', 'EDIT');
                    O.Expect('validated.main', 'EDIT');
                    O.Expect('validated.side', 'side-EDIT');
                    O.Expect('result', 'LookupCancel');
                    O.Expect('returned.main', 'EDIT');
                    O.Expect('returned.side', 'side-EDIT');
                    O.Expect('trace', 'table.validate:EDIT;page.validate:EDIT;page.modify:EDIT;table.modify:1:EDIT;page.query:LookupCancel;page.close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'ListPlus_SaveVeto_ThenOK':
                begin
                    O.Expect('case', 'ListPlus_SaveVeto_ThenOK');
                    O.Expect('before.main', 'seed');
                    O.Expect('before.side', 'side-note');
                    O.Expect('displayed', 'EDIT');
                    O.Expect('validated.main', 'seed');
                    O.Expect('validated.side', 'side-EDIT');
                    O.Expect('after.action.main', 'seed');
                    O.Expect('after.action.side', 'side-EDIT');
                    O.Expect('trace.after.action', 'table.validate:EDIT;page.validate:EDIT;page.modify:EDIT;page.query:OK;page.close;');
                    O.Expect('result', 'OK');
                    O.Expect('returned.main', 'seed');
                    O.Expect('returned.side', 'side-EDIT');
                    O.Expect('trace', 'table.validate:EDIT;page.validate:EDIT;page.modify:EDIT;page.query:OK;page.close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'ListPlus_CloseVeto_ThenSecondOK':
                begin
                    O.Expect('case', 'ListPlus_CloseVeto_ThenSecondOK');
                    O.Expect('before.main', 'seed');
                    O.Expect('before.side', 'side-note');
                    O.Expect('displayed', 'EDIT');
                    O.Expect('validated.main', 'seed');
                    O.Expect('validated.side', 'side-EDIT');
                    O.Expect('after.veto', 'EDIT');
                    O.Expect('vetoed.main', 'EDIT');
                    O.Expect('vetoed.side', 'side-EDIT');
                    O.Expect('result', 'OK');
                    O.Expect('returned.main', 'EDIT');
                    O.Expect('returned.side', 'side-EDIT');
                    O.Expect('trace', 'table.validate:EDIT;page.validate:EDIT;page.modify:EDIT;table.modify:1:EDIT;page.query:OK;page.query:OK;page.close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'ListPlus_ValidateError_ThenCancel':
                begin
                    O.Expect('case', 'ListPlus_ValidateError_ThenCancel');
                    O.Expect('before.main', 'seed');
                    O.Expect('before.side', 'side-note');
                    O.Expect('validate.error|text', 'Validation error for Field: Value,  Message = ''modal form validation failure''');
                    O.Expect('validate.error|code', 'TestValidation');
                    O.Expect('displayed', 'seed');
                    O.Expect('validated.main', 'seed');
                    O.Expect('validated.side', 'side-note');
                    O.Expect('result', 'LookupCancel');
                    O.Expect('returned.main', 'seed');
                    O.Expect('returned.side', 'side-note');
                    O.Expect('trace', 'table.validate:EDIT;page.query:LookupCancel;page.close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            'ListPlus_ValidateCommitError_ThenCancel':
                begin
                    O.Expect('case', 'ListPlus_ValidateCommitError_ThenCancel');
                    O.Expect('before.main', 'seed');
                    O.Expect('before.side', 'side-note');
                    O.Expect('validate.error|text', 'Validation error for Field: Value,  Message = ''modal form committed validation failure''');
                    O.Expect('validate.error|code', 'TestValidation');
                    O.Expect('displayed', 'seed');
                    O.Expect('validated.main', 'seed');
                    O.Expect('validated.side', 'side-EDIT');
                    O.Expect('result', 'LookupCancel');
                    O.Expect('returned.main', 'seed');
                    O.Expect('returned.side', 'side-EDIT');
                    O.Expect('trace', 'table.validate:EDIT;page.query:LookupCancel;page.close;');
                    O.Expect('capture.end', 'COMPLETE');
                end;
            else Error('Unknown modal form observation: %1', Identity);
        end;
    end;
}
