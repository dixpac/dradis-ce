# A Note in dradis is the basic unit of information. It has a :text and an
# :author field that capture the contents of the Note and the creator.
#
# In Dradis 2.x notes have a fixed set of fields (:text, :author, :category,
# :node). However, it is expected that in Dradis 3.x it will be possible to
# configure this list of fields to match the needs of the users.
#
# In the interim, Dradis 2.x Note objects use a special syntax in their :text
# field to define different fields. This syntax is as follows:
#
#   #[Title]#
#   Directory Listings
#
#   #[Description]#
#   Some directories on the server were configured [...]
#
# The syntax above would result in the call to the fields method to return a
# Hash with two elements:
#
#   {
#     'Title' => 'Directory Listings',
#     'Description' => 'Some directories on the server were configured [...]',
#   }
#
#
# This behaviour is extensively used by import/export plugins such as WordExport.
class Note < ActiveRecord::Base
  include HasFields

  dradis_has_fields_for :text

  has_paper_trail

  # -- Relationships --------------------------------------------------------
  belongs_to :category
  belongs_to :node, touch: true
  has_many :activities, as: :trackable

  # -- Callbacks ------------------------------------------------------------


  # -- Validations ----------------------------------------------------------
  validates :category, presence: true
  validates :node, presence: true
  validates :text, length: { maximum: 65535 }


  # -- Scopes ---------------------------------------------------------------
  scope :recently_created, -> { where(['notes.created_at > ?', 1.day.ago]) }
  scope :recently_updated, -> { where(['notes.updated_at > ?', 1.day.ago]) }

  # -- Class Methods --------------------------------------------------------

  # searches non issue notes using case insensitive LIKE
  # returns list of notes matches orered by updated_at desc
  def self.search(term:)
    where("category_id != 2 AND text LIKE :term", term: "%#{term}%")
      .select(:id, :text, :node_id, :updatet_at)
      .order(updated_at: :desc)
  end


  # -- Instance Methods -----------------------------------------------------

  def field_or_text(field_name)
    fields.fetch(field_name, text.truncate(20))
  end
end
