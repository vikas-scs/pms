class ApplicationController < ActionController::Base
	before_action :configure_permitted_parameters, if: :devise_controller?
  # skip_before_action :verify_authenticity_token
	# protect_from_forgery with: :exception
  

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :mobile, :organization_id])  
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :mobile, :organization_id, :image])
  end

   def after_sign_in_path_for(resource)
   	puts "login path"
   	puts resource.class
    # check for the class of the object to determine what type it is
    case resource.class.to_s
    when "User"
    	root_path
      # new_user_session_path  
    when "Admin"
      puts "hello"
    	rails_admin_path
      # new_admin_session_path
    end
  end


end
