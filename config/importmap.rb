# Pin npm packages by running ./bin/importmap

# Explicitly pin application.js with full path to help importmap find it in production
pin "application", to: "application.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true

# Pin controllers explicitly to ensure they're found in production
pin_all_from "app/javascript/controllers", under: "controllers"

# External libraries via CDN
# Sortable.js for drag-and-drop
pin "sortablejs", to: "https://cdn.jsdelivr.net/npm/sortablejs@1.15.0/+esm"
# SparkMD5 for MD5 checksum calculation
pin "spark-md5", to: "https://cdn.jsdelivr.net/npm/spark-md5@3.0.2/+esm"

# Trix rich text editor (via CDN for ESM support)
pin "trix", to: "https://cdn.jsdelivr.net/npm/trix@2.0.0/dist/trix.esm.min.js"
pin "@rails/actiontext", to: "actiontext.esm.js"

# ActionCable for real-time features
pin "@rails/actioncable", to: "actioncable.esm.js"
pin_all_from "app/javascript/channels", under: "channels"
