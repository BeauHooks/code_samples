#
# The funky verison of this require is temporary for as long as we still have
# scripts (kingston-export.rb anyone?) that use rails models w/out loading the
# full rails environment. When this changes, change the require below to a
# simple: require "drive_map"
#
require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "lib", "drive_map"))

class FileImage < ActiveRecord::Base
  self.table_name  = "tblFileImages"
  self.primary_key = "ImageID"

  belongs_to :file_info,                                              foreign_key: "FileID",        primary_key: "FileID"
  belongs_to :vendor_trak_file_info,                                  foreign_key: "FileID",        primary_key: "FileID"
  belongs_to :cpl,             class_name: 'ClosingProtectionLetter', foreign_key: "FileID",        primary_key: "File_id"
  has_many   :delivery_items,                                         foreign_key: "ImageID",       primary_key: "ImageID", order: "DeliveryID"
  has_many   :deliveries,      through: :delivery_items
  has_one    :current_cpl,     class_name: 'ClosingProtectionLetter', foreign_key: "file_image_id", primary_key: "ImageID"

  # Employee Action-Tracking Relationships
  belongs_to :private_by,      class_name: "Employee",                foreign_key: "PrivateBy",     primary_key: "ID"
  belongs_to :entered_by,      class_name: "Employee",                foreign_key: "EnteredBy",     primary_key: "ID"

  # Get the windows and linux versions of the path respectively
  def win_path
    self.FullFileName
  end

  def posix_path
    DriveMap[self.FullFileName]
  end

  # Attempts to take the image's path and correct it using DriveMap.correct. If
  # it turns out the path is invalid, then the image's path will be "marked"
  # (any pre-existing value will be prefixed with "** ", see DriveMap). So,
  # either the path is exactly correct in which case no change is made to the
  # record in the database, or the path for the record is updated by a marked
  # or repaired version.
  #
  # If the impage's path is valid (or was able to be repaired) then true is
  # returned. Otherwise false is returned.
  #
  def repair_path
    result   = false
    repaired = DriveMap.correct(self.FullFileName)
    if repaired
      self.FullFileName = repaired
      result            = true
    else
      repaired = DriveMap.mark(self.FullFileName)
      self.FullFileName = repaired unless DriveMap.blank?(self.FullFileName)
    end
    self.FixMe = false
    self.save! if self.changed?
    result
  end

  # NOTICE: This is really a big fat TODO: fix all image paths in database and
  #         get them better organized.
  #
  # This is used to associate an image's type (ImageType field) with info that
  # can be used to come up with one or more paths where the image may be
  # stored(if the FullFileName field is corrupted, for instance) and where, by
  # default, the image *should* be stored (when creating a new image record of
  # the specified type or otherwise normalizing image locations).
  #
  # The hash keys are regular expressions that are used to match against a
  # text string that describes the image's type (NOT file type). We have to be
  # flexible like this (and not just have a static string) because historic
  # code and database records (may) have several equivalent forms for the same
  # image type.
  #
  # The hash value is itself a hash containing the pertinent information with
  # the following sub-hash keys:
  #
  #   :default ==> text string to use when creating/normalizing image type field strings
  #   :paths   ==> ordered array of strings (more info below) of location(s) where images of this type are stored
  #
  # The :paths element above should contain absolute, posix paths (using paths
  # whose bases match one of the values in DRIVEMAP hash above). Also, the
  # :paths array's order matters. Specifically, the first path is the default
  # used when creating new images/files or normalizing the locations of
  # existing ones.
  #
  # Finally, the :paths are actually base-path specifications. They may have
  # as one of the directory components the special character sequence "%c" or
  # "%C" that indicates the special (and optional) "company" directory. This
  # makes it so that for each path listed, there may be two paths checked when
  # looking for potential matches (such as when trying to guess/repair messed-
  # up FullFileName fields). One where the "%c" compenent is omittted and one
  # where the "%c" is replaced by the special "company" directory sequence
  # (the DirName field of the company associated with the image).
  #
  # By default, only files whos type has a path list entry that DOES NOT have
  # a "%c" company directory indicator or files associated with company 101
  # (Southern Utah Title Company) are allowed to have images that ARE NOT
  # segregated by company.
  #
  # Example:
  # --------
  # Path Specification:  '/k/ftimages/%c/chain'
  # Company:             101 (Southern Utah Title Company)
  # Company's DirName:   'SUTC'
  # Possible Base Paths: /k/ftimages/SUTC/chain --OR-- /k/ftimages/chain
  #
  # When creating/normilizing image files/records, if a path exists that
  # includes the company component then it will be used in preference to the
  # version that doesn't include the company.
  #
  # NOTE: when searching if a company-specific directory exists, a case-
  #       insensitive check is made and the first match found used as the form
  #       entered to create the FullImagePath.
  #
  # NOTE: the DirName field of a company may include several directory levels.
  #       If so, the windows directory separator (backslash) is used. Thus,
  #       code directly accessing this field must convert it (as necessary)
  #
  # Example 2:
  # ----------
  # Path Specification:  '/k/ftimages/%c/example'
  # Company:             109 (Equity Escrow Construction Draw)
  # Company's DirName:   'EQESCROW\CONSTRUCTIONDRAW'
  # Possible Base Paths: '/k/ftimages/EQEscrow/ConstructionDraw/example'
  #              --OR--: '/k/ftimages/example'
  #
  # NOTE: For paths that are equivalent (a'la the INTERCHANGABLE hash above)
  #       you don't need to put more than one entry in the paths array, just
  #       put the preferred path in the array.
  #
  TYPES = {
    /^base$/i                                    => {:default => 'Base',            :paths => ['/k/ftimages/%c/base']},
    /^business$/i                                => {:default => 'Business',        :paths => ['/k/ftimages/%c/business', '/k/custdocs/business']},
    /^card$/i                                    => {:default => 'Card',            :paths => ['/k/ftimages/%c/card']},
    /^chain$/i                                   => {:default => 'Chain',           :paths => ['/k/ftimages/%c/chain']},
    /^corporation$/i                             => {:default => 'Corporation',     :paths => ['/k/ftimages/%c/corporation']},
    /^correspondence$/i                          => {:default => 'Correspondence',  :paths => ['/k/ftimages/%c/correspondence', '/k/ftimages/userimages/correspondence', '/k/ftimages/userimages/business/correspondence']},
    /^disb(urse?ment)?$/i                        => {:default => 'Disbursement',    :paths => ['/k/ftimages/%c/disb']},
    /^divorce$/i                                 => {:default => 'Divorce',         :paths => ['/k/ftimages/%c/divorce', '/k/custdocs/divorce']},
    /^drivers ?license$/i                        => {:default => 'Drivers License', :paths => ['/k/ftimages/%c/driverslicense']},
    /^endorsement$/i                             => {:default => 'Endorsement',     :paths => ['/k/ftimages/%c/endorsement']},
    /^fax$/i                                     => {:default => 'Fax',             :paths => ['/k/ftimages/%c/fax']},
    /^final ?docs$/i                             => {:default => 'Final Docs',      :paths => ['/k/ftimages/%c/finaldocs']},
    /^hoa$/i                                     => {:default => 'HOA',             :paths => ['/k/ftimages/%c/hoa']},
    /^hud$/i                                     => {:default => 'HUD',             :paths => ['/k/ftimages/%c/hud']},
    /^inspection(s| ?form)$/i                    => {:default => 'Inspection Form', :paths => ['/k/ftimages/%c/inspectionform']},
    /^invoice$/i                                 => {:default => 'Invoice',         :paths => ['/k/ftimages/%c/invoice']},
    /^loan ?docs$/i                              => {:default => 'Loan Docs',       :paths => ['/k/ftimages/%c/loandocs']},
    /^manual$/i                                  => {:default => 'Manual',          :paths => ['/k/ftimages/%c/manual']},
    /^misc$/i                                    => {:default => 'Misc',            :paths => ['/k/ftimages/%c/misc', '/k/ftimages/userimages/misc']},
    /^notes$/i                                   => {:default => 'Notes',           :paths => ['/k/ftimages/%c/notes']},
    /^(order ?ammend|file ?archive ?ammended)$/i => {:default => 'Order Ammend',    :paths => ['/k/ftimages/%c/orderammend']},
    /^partnership$/i                             => {:default => 'Partnership',     :paths => ['/k/ftimages/%c/partnership', '/k/custdocs/partnership']},
    /^payoff ?city$/i                            => {:default => 'Payoff City',     :paths => ['/k/ftimages/%c/payoffcity']},
    /^payoff ?lender$/i                          => {:default => 'Payoff Lender',   :paths => ['/k/ftimages/%c/payofflender']},
    /^payoff ?other$/i                           => {:default => 'Payoff Other',    :paths => ['/k/ftimages/%c/payoffother']},
    /^plat$/i                                    => {:default => 'Plat',            :paths => ['/k/ftimages/%c/plat']},
    /^poa$/i                                     => {:default => 'POA',             :paths => ['/k/ftimages/%c/poa']},
    /^policy ?and ?proc$/i                       => {:default => 'Policy and Proc', :paths => ['/k/ftimages/%c/polnproc']},
    /^pr$/i                                      => {:default => 'PR',              :paths => ['/k/ftimages/%c/pr']},
    /^rates$/i                                   => {:default => 'Rates',           :paths => ['/k/ftimages/%c/rates']},
    /^rec(ei|ie)pt$/i                            => {:default => 'Receipt',         :paths => ['/k/ftimages/%c/receipt']},
    /^reconveyance$/i                            => {:default => 'Reconveyance',    :paths => ['/k/ftimages/%c/reconveyance']},
    /^recordeddoc$/i                             => {:default => 'RecordedDoc',     :paths => ['/k/ftimages/%c/recordeddoc']}
  }

#
# When searching for out-of-place stuff: /k/ftimages/trust may have type 'partnership' and 'poa' docs
# 49 images of type 'Litigation Report' stored under a 'pr' subdir
#  1 image of type 'Trustees Sale Guarantee' stored under a 'pr' subdir
#  1 image of type 'PRPACKAGE' (broken) is stored under a 'pr' subdir
#  1 image of type 'REPC' in a repcaddendum subdir
#

end
