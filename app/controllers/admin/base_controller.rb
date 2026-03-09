class Admin::BaseController < ApplicationController
  before_action :ensure_admin!
end
