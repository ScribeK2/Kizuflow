import { application } from "./application"

// Manually import and register all controllers for esbuild compatibility
// This ensures esbuild can statically analyze and bundle all controllers

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

// Register all controllers with Stimulus
// Convert controller filename to Stimulus identifier (e.g., workflow_builder_controller -> workflow-builder)
function registerController(Controller, filename) {
  const name = filename
    .replace(/_controller$/, '')
    .replace(/_/g, '-')
  
  if (!application.router.modulesByIdentifier.has(name)) {
    application.register(name, Controller)
  }
}

// Register all controllers
registerController(AutosaveController, "autosave_controller")
registerController(DarkModeController, "dark_mode_controller")
registerController(FileAttachmentController, "file_attachment_controller")
registerController(FileUploadController, "file_upload_controller")
registerController(FlowPreviewController, "flow_preview_controller")
registerController(GroupSelectorController, "group_selector_controller")
registerController(GroupTreeController, "group_tree_controller")
registerController(ModalController, "modal_controller")
registerController(MultiBranchController, "multi_branch_controller")
registerController(PreviewUpdaterController, "preview_updater_controller")
registerController(QuestionFormController, "question_form_controller")
registerController(RichTextEditorController, "rich_text_editor_controller")
registerController(RuleBuilderController, "rule_builder_controller")
registerController(SearchableDropdownController, "searchable_dropdown_controller")
registerController(StepFormController, "step_form_controller")
registerController(StepModalController, "step_modal_controller")
registerController(StepTemplateController, "step_template_controller")
registerController(StepsController, "steps_controller")
registerController(TemplateFlowPreviewController, "template_flow_preview_controller")
registerController(WizardFlowPreviewController, "wizard_flow_preview_controller")
registerController(WizardNavigationController, "wizard_navigation_controller")
registerController(WorkflowBuilderController, "workflow_builder_controller")
registerController(WorkflowCollaborationController, "workflow_collaboration_controller")
registerController(WorkflowSearchController, "workflow_search_controller")
registerController(WorkflowSidebarController, "workflow_sidebar_controller")
