module Coursewareable
  # Asset/Upload STI model
  class Asset < ActiveRecord::Base
    attr_accessible :description

    # Relationships
    belongs_to :user
    belongs_to :classroom
    belongs_to :assetable, :polymorphic => true
    delegate :url, :to => :attachment

    # Validations
    validates_presence_of :user, :classroom, :assetable
    validates_attachment_presence :attachment

    # Callbacks

    # Cleanup description before saving it
    before_validation do
      self.description = Sanitize.clean(self.description)
    end

    # Increment user used space
    after_create do
      user.plan.increment!(:used_space, attachment_file_size)
    end

    # Decrement freed space
    before_destroy do
      user.plan.decrement!(:used_space, attachment_file_size)
    end

    # Check for left space
    before_save do
      attachment_file_size < user.plan.left_space ? true : false
    end

  end
end
