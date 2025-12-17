class ApplicationController < ActionController::API
  include JsonWebTokenAuthentication
end
