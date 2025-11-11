import { application } from "./application"

// Manually import and register all controllers for esbuild compatibility
// This ensures esbuild can statically analyze and bundle all controllers
// IMPORTANT: Controllers are stored in an array to prevent tree-shaking

// Import all controllers
import AutosaveController from "./autosave_controller"
import DarkModeController from "./dark_mode_controller"
import FileAttachmentController from "./file_attachment_controller"
import FileUploadController from "./file_upload_controller"
import FlowPreviewController from "./flow_preview_controller"
import GroupSelectorController from "./group_selector_controller"
import GroupTreeController from "./group_tree_controller"
import ModalController from "./modal_controller"
import MultiBranchController from "./multi_branch_controller"
import PreviewUpdaterController from "./preview_updater_controller"
import QuestionFormController from "./question_form_controller"
import RichTextEditorController from "./rich_text_editor_controller"
import RuleBuilderController from "./rule_builder_controller"
import SearchableDropdownController from "./searchable_dropdown_controller"
import StepFormController from "./step_form_controller"
import StepModalController from "./step_modal_controller"
import StepTemplateController from "./step_template_controller"
import StepsController from "./steps_controller"
import TemplateFlowPreviewController from "./template_flow_preview_controller"
import WizardFlowPreviewController from "./wizard_flow_preview_controller"
import WizardNavigationController from "./wizard_navigation_controller"
import WorkflowBuilderController from "./workflow_builder_controller"
import WorkflowCollaborationController from "./workflow_collaboration_controller"
import WorkflowSearchController from "./workflow_search_controller"
import WorkflowSidebarController from "./workflow_sidebar_controller"

// Store controllers in an array to prevent tree-shaking
// This ensures esbuild includes all controllers in the bundle
const controllers = [
  { Controller: AutosaveController, name: "autosave" },
  { Controller: DarkModeController, name: "dark-mode" },
  { Controller: FileAttachmentController, name: "file-attachment" },
  { Controller: FileUploadController, name: "file-upload" },
  { Controller: FlowPreviewController, name: "flow-preview" },
  { Controller: GroupSelectorController, name: "group-selector" },
  { Controller: GroupTreeController, name: "group-tree" },
  { Controller: ModalController, name: "modal" },
  { Controller: MultiBranchController, name: "multi-branch" },
  { Controller: PreviewUpdaterController, name: "preview-updater" },
  { Controller: QuestionFormController, name: "question-form" },
  { Controller: RichTextEditorController, name: "rich-text-editor" },
  { Controller: RuleBuilderController, name: "rule-builder" },
  { Controller: SearchableDropdownController, name: "searchable-dropdown" },
  { Controller: StepFormController, name: "step-form" },
  { Controller: StepModalController, name: "step-modal" },
  { Controller: StepTemplateController, name: "step-template" },
  { Controller: StepsController, name: "steps" },
  { Controller: TemplateFlowPreviewController, name: "template-flow-preview" },
  { Controller: WizardFlowPreviewController, name: "wizard-flow-preview" },
  { Controller: WizardNavigationController, name: "wizard-navigation" },
  { Controller: WorkflowBuilderController, name: "workflow-builder" },
  { Controller: WorkflowCollaborationController, name: "workflow-collaboration" },
  { Controller: WorkflowSearchController, name: "workflow-search" },
  { Controller: WorkflowSidebarController, name: "workflow-sidebar" },
]

// Register all controllers with Stimulus
// This side-effect ensures controllers are included in the bundle
controllers.forEach(({ Controller, name }) => {
  if (!application.router.modulesByIdentifier.has(name)) {
    application.register(name, Controller)
  }
})

// Export controllers array to prevent tree-shaking (side-effect)
// This ensures esbuild includes all controller code
export { controllers }
