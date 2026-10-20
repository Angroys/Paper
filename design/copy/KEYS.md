# ARB key mapping

`app_en.arb` key names follow `design/specs/copy-keys.txt`. This note maps the first ARB draft (362 keys) to the reconciled one (476 keys, all 383 spec keys present).

## Renamed (old key → spec key)

The slot carried over. Most strings were kept; some were tightened to fit the spec slot.

| Old key | New key |
| --- | --- |
| `a11yPanelDivider` | `readerPanelResizeLabel` |
| `a11yPdfPage` | `readerPageIndicator` |
| `a11ySyncStatus` | `syncBadgeSemantics` |
| `aiErrorTitle` | `aiExplainFailed` |
| `aiOfflineCached` | `aiCachedExplanation` |
| `aiOfflineTitle` | `authOfflineTitle` |
| `appTagline` | `signInTagline` |
| `authBrowserOpenedBody` | `authBrowserWaitBody` |
| `authBrowserOpenedTitle` | `authBrowserWaitTitle` |
| `authContinueWithGoogle` | `signInGoogle` |
| `authCreateAccountButton` | `signUpSubmit` |
| `authEmailLabel` | `signInEmailLabel` |
| `authErrorCancelled` | `authGoogleCancelled` |
| `authErrorDeepLink` | `authCodeExchangeFailed` |
| `authErrorInvalidCredentials` | `authInvalidCredentials` |
| `authErrorInvalidEmail` | `authEmailInvalid` |
| `authErrorTooManyAttempts` | `authRateLimited` |
| `authForgotPassword` | `signInForgotPassword` |
| `authHaveAccount` | `signInHaveAccountPrompt` |
| `authMagicLinkSentBody` | `authCheckEmailBody` |
| `authMagicLinkSentTitle` | `authCheckEmailTitle` |
| `authNoAccount` | `signInCreateAccountPrompt` |
| `authOrDivider` | `signInDividerOr` |
| `authPasswordLabel` | `signInPasswordLabel` |
| `authPrivacy` | `signInPrivacy` |
| `authResendIn` | `authResendCooldown` |
| `authResetSentBody` | `authResetSent` |
| `authSendMagicLink` | `signInMagicLink` |
| `authSignInButton` | `signInSubmit` |
| `authSignInTitle` | `signInScreenHeading` |
| `authSignOut` | `settingsSignOut` |
| `authSignOutConfirmBody` | `signOutConfirmBody` |
| `authSignOutConfirmTitle` | `signOutConfirmTitle` |
| `authSignOutPendingBody` | `signOutPendingBody` |
| `authTerms` | `signInTerms` |
| `authUseDifferentEmail` | `authUseAnotherEmail` |
| `citationAddError` | `citationImportFailed` |
| `citationAddToLibrary` | `citationImport` |
| `citationAdded` | `citationImported` |
| `citationJumpToReference` | `citationGoToReference` |
| `citationLookingUp` | `citationLoading` |
| `citationOfflineNote` | `citationOfflineHint` |
| `citationOpenSource` | `citationOpenLink` |
| `libraryAddedOn` | `paperMetaAdded` |
| `libraryDelete` | `paperMenuDelete` |
| `libraryDeleteConfirmBody` | `libraryDeleteManyBody` |
| `libraryDeleteConfirmTitle` | `libraryDeleteManyTitle` |
| `libraryDeleted` | `libraryDeletedUndo` |
| `libraryDeletedMany` | `libraryDeletedManyUndo` |
| `libraryDownload` | `paperMenuDownload` |
| `libraryDownloadFailed` | `downloadStateFailed` |
| `libraryDownloadQueued` | `downloadStateQueued` |
| `libraryDownloaded` | `downloadStateAvailable` |
| `libraryDownloading` | `downloadStateDownloading` |
| `libraryImport` | `importButton` |
| `libraryImportDropHint` | `libraryEmptyDropHint` |
| `libraryImportErrorNotPdf` | `importUrlNotPdf` |
| `libraryImportErrorOffline` | `importOfflineUrl` |
| `libraryImportErrorTimeout` | `importUrlFetchFailed` |
| `libraryImportErrorUrlInvalid` | `importUrlInvalid` |
| `libraryImportOpen` | `importOpenExisting` |
| `libraryImportSheetTitle` | `importUrlDialogTitle` |
| `libraryImportSuccess` | `importSuccess` |
| `libraryImportUploading` | `importUploading` |
| `libraryImportUrlLabel` | `importUrlFieldLabel` |
| `libraryImportUrlSubmit` | `importUrlSubmit` |
| `libraryNavLabel` | `navLibrary` |
| `libraryNotDownloadedOffline` | `readerUnavailableOffline` |
| `libraryOfflineFilter` | `libraryFilterDownloaded` |
| `libraryPageCount` | `paperMetaPages` |
| `libraryRemoveDownload` | `paperMenuRemoveDownload` |
| `libraryRename` | `paperMenuRename` |
| `libraryRenameErrorEmpty` | `renameEmptyError` |
| `libraryRenameSave` | `renameSave` |
| `libraryRenameTitle` | `renameDialogTitle` |
| `librarySortLastOpened` | `librarySortRecentlyOpened` |
| `librarySortNewest` | `librarySortRecentlyAdded` |
| `offlineFeatureUnavailable` | `aiNeedsConnection` |
| `onboardingHighlightBody` | `onboardingExplainBody` |
| `onboardingHighlightTitle` | `onboardingExplainTitle` |
| `onboardingStep` | `onboardingPageIndicator` |
| `onboardingWelcomeBody` | `onboardingReadBody` |
| `onboardingWelcomeTitle` | `onboardingReadTitle` |
| `panelExplanationAnalogy` | `explanationAnalogyHeading` |
| `panelExplanationEmptyBody` | `explanationEmptyBody` |
| `panelExplanationEmptyTitle` | `explanationEmptyTitle` |
| `panelExplanationFormal` | `explanationFormalHeading` |
| `panelExplanationTab` | `panelTabExplanation` |
| `panelGlossaryEmptyBody` | `glossaryEmptyBody` |
| `panelGlossarySearchHint` | `glossaryFilterHint` |
| `panelGlossaryTab` | `panelTabGlossary` |
| `panelNoteDelete` | `noteDelete` |
| `panelNoteDeleted` | `noteDeletedUndo` |
| `panelNoteHint` | `noteInlinePlaceholder` |
| `panelNoteSaved` | `noteSaved` |
| `panelNotesEmptyBody` | `notesEmptyBody` |
| `panelNotesEmptyTitle` | `notesEmptyTitle` |
| `panelNotesTab` | `panelTabNotes` |
| `panelReexplain` | `explanationReexplain` |
| `panelReexplaining` | `explanationReexplaining` |
| `panelResize` | `readerPanelResizeLabel` |
| `readerColorBlue` | `highlightColorBlue` |
| `readerColorGreen` | `highlightColorGreen` |
| `readerColorOrange` | `highlightColorOrange` |
| `readerColorPink` | `highlightColorPink` |
| `readerColorPurple` | `highlightColorPurple` |
| `readerColorYellow` | `highlightColorYellow` |
| `readerEraserTool` | `readerToolEraser` |
| `readerFigureTool` | `readerToolFigure` |
| `readerGoToPageError` | `readerPageOutOfRange` |
| `readerHighlightDelete` | `highlightDelete` |
| `readerHighlightDeleted` | `highlightDeletedUndo` |
| `readerHighlightTool` | `readerToolHighlight` |
| `readerLoadError` | `readerRenderFailed` |
| `readerPageOf` | `readerPageIndicator` |
| `readerSearch` | `readerFind` |
| `readerSearchNoResults` | `readerFindNoResults` |
| `readerSearchResults` | `readerFindResultCount` |
| `readerSelectTool` | `readerToolSelect` |
| `readerSelectionAddNote` | `selectionNote` |
| `readerSelectionCopied` | `selectionCopied` |
| `readerSelectionCopy` | `selectionCopy` |
| `readerSelectionExplain` | `selectionExplain` |
| `readerSplitView` | `readerTogglePanel` |
| `readerStylusModeOn` | `readerStylusHint` |
| `readerStylusTool` | `readerToolPen` |
| `settingsAbout` | `settingsSectionAbout` |
| `settingsAccount` | `settingsSectionAccount` |
| `settingsAppearance` | `settingsSectionAppearance` |
| `settingsClearDownloads` | `storageRemoveAll` |
| `settingsClearDownloadsConfirm` | `storageRemoveAllBody` |
| `settingsDownloadOnWifiOnly` | `autoDownloadWifi` |
| `settingsHelp` | `aboutFeedback` |
| `settingsLicenses` | `aboutLicenses` |
| `settingsOffline` | `settingsSectionStorage` |
| `settingsPrivacy` | `aboutPrivacy` |
| `settingsReader` | `settingsSectionReader` |
| `settingsScrollHorizontal` | `scrollHorizontal` |
| `settingsScrollVertical` | `scrollVertical` |
| `settingsShortcuts` | `aboutShortcuts` |
| `settingsStylusOnly` | `settingsAutoPen` |
| `settingsSync` | `settingsSectionSync` |
| `settingsTerms` | `aboutTerms` |
| `settingsThemeDark` | `themeDark` |
| `settingsThemeLight` | `themeLight` |
| `settingsThemeSystem` | `themeSystem` |
| `settingsVersion` | `aboutVersion` |
| `shortcutsOpenPaper` | `shortcutsImportFile` |
| `shortcutsTitle` | `shortcutsDialogTitle` |
| `syncConflictBody` | `syncHowItWorksBody` |
| `syncConflictTitle` | `syncHowItWorksTitle` |
| `syncErrorAuth` | `syncAuthExpired` |
| `syncNever` | `syncNeverSynced` |
| `syncPending` | `syncPendingCount` |
| `syncSynced` | `syncStateSynced` |
| `syncSyncing` | `syncStateSyncing` |

## Dropped (no spec slot, not a generic key)

Re-add a key only after the UX spec gives it a slot.

`a11ySearchResultsCount`, `aiErrorBody`, `aiGenerating`, `aiOfflineBody`, `aiQuotaBody`, `aiQuotaResetAt`, `aiQuotaTitle`, `aiSelectionTooLong`, `aiTimeout`, `authConfirmEmailBody`, `authCreatingAccount`, `authEmailHint`, `authErrorEmailInUse`, `authErrorEmailNotConfirmed`, `authErrorGeneric`, `authErrorLinkExpired`, `authErrorPasswordTooShort`, `authLegalNotice`, `authPasswordHint`, `authReturnedSuccess`, `authReturningTitle`, `authSignInSubtitle`, `authUseMagicLinkInstead`, `authUsePasswordInstead`, `citationAdding`, `citationAuthorsEtAl`, `citationCopied`, `citationCopy`, `citationNoOpenAccess`, `citationYear`, `libraryDeleteUndone`, `libraryDownloadCancel`, `libraryDownloadRetry`, `libraryEmptyImportFile`, `libraryEmptyImportUrl`, `libraryHighlightCount`, `libraryImportErrorGeneric`, `libraryImportErrorUrlEmpty`, `libraryImportFetching`, `libraryImportFile`, `libraryImportFileHelper`, `libraryImportPreparing`, `libraryImportUrlHelper`, `libraryImportUrlHint`, `libraryPaperCount`, `libraryRemoveDownloadDone`, `libraryRenameLabel`, `libraryRenamed`, `librarySubtitle`, `libraryUntitled`, `offlineBackOnline`, `offlineBanner`, `offlineBannerShort`, `offlineLibraryEmptyBody`, `offlineLibraryEmptyTitle`, `offlineStorageUsed`, `onboardingGlossaryBody`, `onboardingGlossaryTitle`, `panelExplanationLoading`, `panelExplanationVisual`, `panelExplanationVisualError`, `panelExplanationVisualLoading`, `panelGlossaryAllPapers`, `panelGlossaryEmptyTitle`, `panelGlossaryTermCount`, `panelGlossaryThisPaper`, `panelNoteOnPage`, `panelNoteSavedOffline`, `panelNoteSaving`, `panelNotesNew`, `panelSaveToGlossary`, `panelSavedToGlossary`, `readerExitFullscreen`, `readerFigureHint`, `readerFullscreen`, `readerGoToPageHint`, `readerHideSplitView`, `readerHighlightChangeColor`, `readerHighlightEditNote`, `readerLoadErrorBody`, `readerNoOutline`, `readerOpening`, `readerOutline`, `readerPageShort`, `readerPasswordProtected`, `readerSearchHint`, `readerSelectionHighlight`, `readerStylusModeOff`, `settingsDeleteAccount`, `settingsSignedInAs`, `settingsStylusOnlyHelp`, `syncConflictReplaced`, `syncError`, `syncJustNow`, `syncLastSyncedAt`, `syncPendingShort`

## Keys outside the spec

Generic `common*`, `error*`, `a11y*`, `app*`; `shortcuts*` rows for the ShortcutsDialog (layout-system §9); `settingsReduceMotion*` (motion.md §3.2); `aiPoweredNote` (voice rule 9). They are kept on purpose and are not in `copy-keys.txt`.
