module Coursewareable
  # Coursewareable User model
  class User < ActiveRecord::Base
    include PublicActivity::Model

    # [User] email validation regex
    EMAIL_FORMAT = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i

    authenticates_with_sorcery! do |config|
      config.authentications_class = ::Coursewareable::Authentication
    end

    attr_accessible :email, :password, :password_confirmation,
      :first_name, :last_name, :description, :authentications_attributes

    # Relationships
    has_many :authentications, :dependent => :destroy

    has_many(
      :created_classrooms, :dependent => :destroy,
      :class_name => Classroom, :foreign_key => :owner_id
    )
    has_one :plan

    has_many :associations
    has_many :memberships, :dependent => :destroy
    has_many :collaborations, :dependent => :destroy
    has_many :classrooms, :through => :associations, :source => :classroom
    has_many(:membership_classrooms,
             :through => :memberships, :source => :classroom)
    has_many(:collaboration_classrooms,
             :through => :collaborations, :source => :classroom)
    has_many :images
    has_many :uploads
    has_many :lectures
    has_many :assignments
    has_many :responses, :dependent => :destroy
    has_many :grades
    has_many(
      :received_grades, :dependent => :destroy,
      :foreign_key => :receiver_id, :class_name => Grade
    )
    has_many :invitations, :dependent => :destroy
    has_many(
      :sent_invitations, :dependent => :destroy,
      :class_name => Invitation, :foreign_key => :creator_id
    )

    # Validations
    validates_confirmation_of :password
    validates_presence_of :password, { :on => :create }
    validates_length_of :password, :minimum => 6, :maximum => 32

    validates_presence_of :email
    validates_uniqueness_of :email
    validates_format_of :email, :with => EMAIL_FORMAT, :on => :create
    validates_length_of :description, :maximum => 1000

    # Nested attributes
    accepts_nested_attributes_for :authentications
    accepts_nested_attributes_for :associations, :update_only => true

    # Enable public activity
    activist

    # Hooks
    before_create do |user|
      plan = Coursewareable.config.plans[:free]
      user.plan = Plan.create(plan.except(:cost))
    end
    # Cleanup description before saving it
    before_save do
      self.description = Sanitize.clean(
        self.description, Sanitize::Config::RESTRICTED)
    end
    # Update invitations, if any, related to user email address
    after_create do
      invites = Invitation.where(:email => self.email)
      return if invites.empty?

      invites.each do |inv|
        inv.update_attributes(:user_id => self.id)

        role = inv.role.constantize unless inv.role.nil?
        inv.classroom.members << self if role == Coursewareable::Membership
        inv.classroom.collaborators << self if (
          role == Coursewareable::Collaboration)
      end
    end

    # Helper to generate user's name
    def name
      return [first_name, last_name].join(' ').strip if first_name or last_name
      # Get just first 3 chars and truncate the rest
      email_name = email.split('@').first
      email.sub(email_name, email_name.truncate(3, :omission => '') + '...')
    end

    # Sugaring to count created collaborations across created classrooms
    def created_classrooms_collaborations_count
      created_classrooms.map(&:collaborations_count).reduce(:+).to_i
    end

  end
end
