module SimulationsHelper
  def simulation_back_button(simulation)
    return nil unless simulation.execution_path.present? && simulation.execution_path.length > 0

    link_to step_simulation_path(simulation, back: true),
            class: "inline-flex items-center bg-white/50 dark:bg-gray-800/50 py-2 px-4 border border-slate-200 dark:border-slate-700 rounded-lg shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 hover:bg-white/80 dark:hover:bg-gray-800/80 transition-all duration-200 hover:scale-105" do
      raw('<svg class="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path></svg>') + "Back"
    end
  end
end
