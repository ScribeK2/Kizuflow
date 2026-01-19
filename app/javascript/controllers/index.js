// This file uses importmap-rails with stimulus-loading for automatic controller loading

import { application } from "./application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

eagerLoadControllersFrom("controllers", application)
