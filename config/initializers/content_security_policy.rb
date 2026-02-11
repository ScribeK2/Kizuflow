# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data, "fonts.googleapis.com", "fonts.gstatic.com"
  policy.img_src     :self, :https, :data, :blob
  policy.object_src  :none
  policy.script_src  :self, :https
  policy.style_src   :self, :https, :unsafe_inline
  policy.connect_src :self, :https, "wss:"

  # Specify URI for violation reports (optional - enable for debugging)
  # policy.report_uri "/csp-violation-report-endpoint"
end

# Generate session nonces for permitted importmap and inline scripts
Rails.application.config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
Rails.application.config.content_security_policy_nonce_directives = %w[script-src]

# Report CSP violations to a specified URI (enable for debugging/monitoring)
# See https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy-Report-Only
# Rails.application.config.content_security_policy_report_only = true
