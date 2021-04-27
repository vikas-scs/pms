require 'rotp'
require 'devise_google_authenticatable/hooks/totp_authenticatable'
module Devise # :nodoc:
  module Models # :nodoc:
    module GoogleAuthenticatable
      def self.included(base) # :nodoc:
        base.extend ClassMethods

        base.class_eval do
          before_validation :assign_auth_secret, on: :create
          include InstanceMethods

          # Allow base model to override the gauth_enabled? method
          unless base.method_defined?(:gauth_enabled?)
            include GauthEnabledInstanceMethod
          end
        end
      end

      module InstanceMethods # :nodoc:
        # Is the TOTP Authentication enabled
        def with_totp_authentication?
          gauth_enabled.to_i != 0
        end

        def get_qr
          gauth_secret
        end

        def set_gauth_enabled(param)
          update(gauth_enabled: param)
        end

        def assign_tmp
          update(gauth_tmp: ROTP::Base32.random_base32(32),
                            gauth_tmp_datetime: Time.now)
          gauth_tmp
        end

        def validate_token(token,backup)
          return false if gauth_tmp_datetime.nil?
          puts backup
          return false if gauth_tmp_datetime < self.class.ga_timeout.ago
          valid_vals = []
          valid_vals << backup
          #puts resource.backup_tmp
          valid_vals << ROTP::TOTP.new(get_qr).at(Time.now)
          (1..self.class.ga_timedrift).each do |cc|
            valid_vals << ROTP::TOTP.new(get_qr).at(Time.now.ago(30 * cc))
            valid_vals << ROTP::TOTP.new(get_qr).at(Time.now.in(30 * cc))
          end
          puts "//////"
          puts valid_vals.inspect
          puts token.to_i
          a = valid_vals
          a.delete(0)
          valid_vals.include?(token.to_i)
        end

        def require_token?(cookie)
          return true if self.class.ga_remembertime.nil? || cookie.blank?

          array = cookie.to_s.split ','
          return true if array.count != 2

          last_logged_in_email = array[0]
          last_logged_in_time = array[1].to_i

          last_logged_in_email != email ||
            (Time.now.to_i - last_logged_in_time) > self.class.ga_remembertime
                                                        .to_i
        end

        private

        def assign_auth_secret
          self.gauth_secret = ROTP::Base32.random_base32(64)
        end
      end

      module GauthEnabledInstanceMethod
        def gauth_enabled?
          # Active_record seems to handle determining the status better this way
          if gauth_enabled.respond_to?('to_i')
            gauth_enabled.to_i != 0
          # Mongoid does NOT have a .to_i for the Boolean return value, hence,
          # we can just return it
          else
            gauth_enabled
          end
        end
      end

      module ClassMethods # :nodoc:
        def find_by_gauth_tmp(gauth_tmp)
          where(gauth_tmp: gauth_tmp).first
        end
        ::Devise::Models.config(self, :ga_timeout, :ga_timedrift,
                                :ga_remembertime, :ga_appname,
                                :ga_bypass_signup)
        def resource_params
           params.require(:resources).permit(:backup_tmp)
        end
      end
    end
  end
end
