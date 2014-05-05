module EntityAffiliationHelper
  def relationship_list()
    options = {"Accomodator"=>"Accomodator", 
      "Account Rep"=>"Account Rep", "Accountant"=>"Accountant", "Accounts Payable"=>"Accounts Payable", "Administrator"=>"Administrator", "Advisor"=>"Advisor", 
      "Agency"=>"Agency", "Agent"=>"Agent", "Appraiser"=>"Appraiser", "Assistant"=>"Assistant", "Asst. Manager"=>"Asst. Manager", "Asst. Director"=>"Asst. Director", 
      "Attorney"=>"Attorney", "Attorney-In-Fact"=>"Attorney-In-Fact", "Auditor"=>"Auditor", "Aunt/Nephew"=>"Aunt/Nephew", "Authorized Agent"=>"Authorized Agent", 
      "Authorized Signer"=>"Authorized Signer", "Board Member"=>"Board Member", "Book Keeper"=>"Book Keeper", "Branch Manager"=>"Branch Manager", "Bro/Sis"=>"Bro/Sis", 
      "Broker"=>"Broker", "Brother"=>"Brother", "Brother-In-law"=>"Brother-In-law", "Builder"=>"Builder", "Business"=>"Business", "Business Partner"=>"Business Partner", 
      "Co-Trustee"=>"Co-Trustee", "CEO"=>"CEO", "CFO"=>"CFO", "Chairman"=>"Chairman", "Chairman of Board"=>"Chairman of Board", "Chief Financial Officer"=>"Chief Financial Officer", 
      "Chief Operating Officer"=>"Chief Operating Officer", "City Clerk/Recorder"=>"City Clerk/Recorder", "City Manager"=>"City Manager", "Claims"=>"Claims", 
      "Claims Counsel"=>"Claims Counsel", "Claims Representative"=>"Claims Representative", "Client"=>"Client", "Closer"=>"Closer", "Closing Agent Help"=>"Closing Agent Help", 
      "Closing Coordinator"=>"Closing Coordinator", "CO - Officer"=>"CO - Officer", "CO-Trustee"=>"CO-Trustee", "CO-Personal Representative"=>"CO-Personal Representative", 
      "Co-Worker"=>"Co-Worker", "Coach"=>"Coach", "Commercial Loan Officer"=>"Commercial Loan Officer", "Commission Chair"=>"Commission Chair", "Commission Liason"=>"Commission Liason", 
      "Commissioner"=>"Commissioner", "Community Manager"=>"Community Manager", "Companion"=>"Companion", "Company"=>"Company", "Contact Person"=>"Contact Person", 
      "Controller"=>"Controller", "Council"=>"Council", "Council Member"=>"Council Member", "Counsel"=>"Counsel", "County Manager"=>"County Manager", "CPL"=>"CPL", 
      "Cross Reference"=>"Cross Reference", "Custodian FBO"=>"Custodian FBO", "Daughter"=>"Daughter", "Daughter / Mother"=>"Daughter / Mother", "Daughter/Father"=>"Daughter/Father", 
      "DBA"=>"DBA", "Deceased Spouse"=>"Deceased Spouse", "Developer"=>"Developer", "Development"=>"Development", "Developmental Services"=>"Developmental Services", 
      "Director"=>"Director", "Director of Sales"=>"Director of Sales", "Divorced"=>"Divorced", "Doc Specialist"=>"Doc Specialist", "Economic Development"=>"Economic Development", 
      "ED Chair"=>"ED Chair", "Employee"=>"Employee", "Employer"=>"Employer", "Engineer"=>"Engineer", "Escrow"=>"Escrow", "Escrow Assistant"=>"Escrow Assistant", 
      "Escrow Coordinator"=>"Escrow Coordinator", "Escrow Officer"=>"Escrow Officer", "Ex-Spouse"=>"Ex-Spouse", "Examiner"=>"Examiner", "Exchange Specialist"=>"Exchange Specialist", 
      "Exec. Director"=>"Exec. Director", "Executive Vice President"=>"Executive Vice President", "Executor"=>"Executor", "Family"=>"Family", "Father"=>"Father", 
      "Father-in-law"=>"Father-in-law", "Father/Daughter"=>"Father/Daughter", "Father/Son"=>"Father/Son", "Fiance"=>"Fiance", "Finance Manager"=>"Finance Manager", 
      "Finance Officer"=>"Finance Officer", "Financial"=>"Financial", "Financial Advisor"=>"Financial Advisor", "FKA"=>"FKA", "For Payoffs"=>"For Payoffs", "Friend"=>"Friend", 
      "General Manager"=>"General Manager", "General Partner"=>"General Partner", "General Personal Representative"=>"General Personal Representative", 
      "Boyfriend/Girlfriend"=>"Boyfriend/Girlfriend", "Good Friend"=>"Good Friend", "Granddaughter"=>"Granddaughter", "Grandmother"=>"Grandmother", "Grandson"=>"Grandson", 
      "Grantor"=>"Grantor", "HOA"=>"HOA", "HOA Contact"=>"HOA Contact", "HOA Handler"=>"HOA Handler", "HOA Manager"=>"HOA Manager", "HOA President"=>"HOA President", 
      "HOA Secretary"=>"HOA Secretary", "Human Resources"=>"Human Resources", "Husband/Wife"=>"Husband/Wife", "In-Laws"=>"In-Laws", "IRA"=>"IRA", "Law Firm"=>"Law Firm", 
      "Legal Assistant"=>"Legal Assistant", "Legal/Bond"=>"Legal/Bond", "LENDER"=>"LENDER", "Limited Partner"=>"Limited Partner", "Loan Officer"=>"Loan Officer", 
      "Loan Processor"=>"Loan Processor", "Lobbyist"=>"Lobbyist", "Manager"=>"Manager", "Manager/Member"=>"Manager/Member", "Managing General Partner"=>"Managing General Partner", 
      "Managing Member"=>"Managing Member", "Managing Partner"=>"Managing Partner", "Marketing"=>"Marketing", "Mayor"=>"Mayor", "Member"=>"Member", "Member/President"=>"Member/President", 
      "Membership - VP"=>"Membership - VP", "Minister"=>"Minister", "Mother/Daughter"=>"Mother/Daughter", "Mortgage Specialists"=>"Mortgage Specialists", "Mother/Son"=>"Mother/Son", 
      "National Director"=>"National Director", "Nephew/Uncle"=>"Nephew/Uncle", "Niece/Aunt"=>"Niece/Aunt", "Notary Service"=>"Notary Service", "Office Help"=>"Office Help", 
      "Office Manager"=>"Office Manager", "Officials"=>"Officials", "Operating Manager"=>"Operating Manager", "Organizer"=>"Organizer", "Owner"=>"Owner", "Owner/Developer"=>"Owner/Developer", 
      "Paralegal"=>"Paralegal", "Parent"=>"Parent", "Partner"=>"Partner", "Personal Representative"=>"Personal Representative", "Pilot"=>"Pilot", "President"=>"President", 
      "President-elect"=>"President-elect", "PRINCIPAL"=>"PRINCIPAL", "Processor"=>"Processor", "Program Specialist"=>"Program Specialist", "Project Engineer"=>"Project Engineer", 
      "Project Manager"=>"Project Manager", "Public Services Director"=>"Public Services Director", "QC Officer"=>"QC Officer", "Realtor"=>"Realtor", "Recorder"=>"Recorder", 
      "Recreation Manager"=>"Recreation Manager", "Regional Counsel"=>"Regional Counsel", "Registered Agent"=>"Registered Agent", "Relationship Manager"=>"Relationship Manager", 
      "Relative - Lender"=>"Relative - Lender", "Relative-deceased"=>"Relative-deceased", "Representative"=>"Representative", "Resident Agent"=>"Resident Agent", 
      "Residential Lending Specialist"=>"Residential Lending Specialist", "RESPA Enforcement Officer"=>"RESPA Enforcement Officer", "Sales/Marketing"=>"Sales/Marketing", 
      "Same Person"=>"Same Person", "Searcher"=>"Searcher", "SEC. CO-TRUSTEE"=>"SEC. CO-TRUSTEE", "Secretary"=>"Secretary", "Secretary/Treasurer"=>"Secretary/Treasurer", 
      "Senior Vice-President"=>"Senior Vice-President", "Sibling"=>"Sibling", "Significant other"=>"Significant other", "SISTER"=>"SISTER", "Sister Company"=>"Sister Company", 
      "Sister-in-law"=>"Sister-in-law", "Son"=>"Son", "Son-in-law"=>"Son-in-law", "Son/Father"=>"Son/Father", "Son/Mother"=>"Son/Mother", "Spouse"=>"Spouse", 
      "SR. Vice President"=>"SR. Vice President", "Step-Father"=>"Step-Father", "Sub Contractor"=>"Sub Contractor", "Subordinations"=>"Subordinations", "Successor Trustee"=>"Successor Trustee", 
      "Transaction Coordinator"=>"Transaction Coordinator", "Treasurer"=>"Treasurer", "TRUST"=>"TRUST", "Trustee"=>"Trustee", "Trustee,As General Partner"=>"Trustee,As General Partner", 
      "Trustee/Spouse"=>"Trustee/Spouse", "Uncle"=>"Uncle", "Vice-President"=>"Vice-President"}

    collection = [["Accomodator", "Accomodator"], ["Account Rep", "Account Rep"], ["Accountant", "Accountant"], ["Accounts Payable", "Accounts Payable"], 
    ["Administrator", "Administrator"], ["Advisor", "Advisor"], ["Agency", "Agency"], ["Agent", "Agent"], ["Appraiser", "Appraiser"], ["Assistant", "Assistant"], 
    ["Asst. Manager", "Asst. Manager"], ["Asst. Director", "Asst. Director"], ["Attorney", "Attorney"], ["Attorney-In-Fact", "Attorney-In-Fact"], ["Auditor", "Auditor"], 
    ["Aunt/Nephew", "Aunt/Nephew"], ["Authorized Agent", "Authorized Agent"], ["Authorized Signer", "Authorized Signer"], ["Board Member", "Board Member"], ["Book Keeper", "Book Keeper"], 
    ["Branch Manager", "Branch Manager"], ["Bro/Sis", "Bro/Sis"], ["Broker", "Broker"], ["Brother", "Brother"], ["Brother-In-law", "Brother-In-law"], ["Builder", "Builder"], 
    ["Business", "Business"], ["Business Partner", "Business Partner"], ["Co-Trustee", "Co-Trustee"], ["CEO", "CEO"], ["CFO", "CFO"], ["Chairman", "Chairman"], 
    ["Chairman of Board", "Chairman of Board"], ["Chief Financial Officer", "Chief Financial Officer"], ["Chief Operating Officer", "Chief Operating Officer"], 
    ["City Clerk/Recorder", "City Clerk/Recorder"], ["City Manager", "City Manager"], ["Claims", "Claims"], ["Claims Counsel", "Claims Counsel"], ["Claims Representative", "Claims Representative"], 
    ["Client", "Client"], ["Closer", "Closer"], ["Closing Agent Help", "Closing Agent Help"], ["Closing Coordinator", "Closing Coordinator"], ["CO - Officer", "CO - Officer"], 
    ["CO-Trustee", "CO-Trustee"], ["CO-Personal Representative", "CO-Personal Representative"], ["Co-Worker", "Co-Worker"], ["Coach", "Coach"], ["Commercial Loan Officer", "Commercial Loan Officer"], 
    ["Commission Chair", "Commission Chair"], ["Commission Liason", "Commission Liason"], ["Commissioner", "Commissioner"], ["Community Manager", "Community Manager"], ["Companion", "Companion"], 
    ["Company", "Company"], ["Contact Person", "Contact Person"], ["Controller", "Controller"], ["Council", "Council"], ["Council Member", "Council Member"], ["Counsel", "Counsel"], 
    ["County Manager", "County Manager"], ["CPL", "CPL"], ["Cross Reference", "Cross Reference"], ["Custodian FBO", "Custodian FBO"], ["Daughter", "Daughter"], 
    ["Daughter / Mother", "Daughter / Mother"], ["Daughter/Father", "Daughter/Father"], ["DBA", "DBA"], ["Deceased Spouse", "Deceased Spouse"], ["Developer", "Developer"], 
    ["Development", "Development"], ["Developmental Services", "Developmental Services"], ["Director", "Director"], ["Director of Sales", "Director of Sales"], 
    ["Divorced", "Divorced"], ["Doc Specialist", "Doc Specialist"], ["Economic Development", "Economic Development"], ["ED Chair", "ED Chair"], ["Employee", "Employee"], 
    ["Employer", "Employer"], ["Engineer", "Engineer"], ["Escrow", "Escrow"], ["Escrow Assistant", "Escrow Assistant"], ["Escrow Coordinator", "Escrow Coordinator"], 
    ["Escrow Officer", "Escrow Officer"], ["Ex-Spouse", "Ex-Spouse"], ["Examiner", "Examiner"], ["Exchange Specialist", "Exchange Specialist"], ["Exec. Director", "Exec. Director"], 
    ["Executive Vice President", "Executive Vice President"], ["Executor", "Executor"], ["Family", "Family"], ["Father", "Father"], ["Father-in-law", "Father-in-law"], 
    ["Father/Daughter", "Father/Daughter"], ["Father/Son", "Father/Son"], ["Fiance", "Fiance"], ["Finance Manager", "Finance Manager"], ["Finance Officer", "Finance Officer"], 
    ["Financial", "Financial"], ["Financial Advisor", "Financial Advisor"], ["FKA", "FKA"], ["For Payoffs", "For Payoffs"], ["Friend", "Friend"], ["General Manager", "General Manager"], 
    ["General Partner", "General Partner"], ["General Personal Representative", "General Personal Representative"], ["Boyfriend/Girlfriend", "Boyfriend/Girlfriend"], 
    ["Good Friend", "Good Friend"], ["Granddaughter", "Granddaughter"], ["Grandmother", "Grandmother"], ["Grandson", "Grandson"], ["Grantor", "Grantor"], ["HOA", "HOA"], 
    ["HOA Contact", "HOA Contact"], ["HOA Handler", "HOA Handler"], ["HOA Manager", "HOA Manager"], ["HOA President", "HOA President"], ["HOA Secretary", "HOA Secretary"], 
    ["Human Resources", "Human Resources"], ["Husband/Wife", "Husband/Wife"], ["In-Laws", "In-Laws"], ["IRA", "IRA"], ["Law Firm", "Law Firm"], ["Legal Assistant", "Legal Assistant"], 
    ["Legal/Bond", "Legal/Bond"], ["LENDER", "LENDER"], ["Limited Partner", "Limited Partner"], ["Loan Officer", "Loan Officer"], ["Loan Processor", "Loan Processor"], ["Lobbyist", "Lobbyist"], 
    ["Manager", "Manager"], ["Manager/Member", "Manager/Member"], ["Managing General Partner", "Managing General Partner"], ["Managing Member", "Managing Member"], 
    ["Managing Partner", "Managing Partner"], ["Marketing", "Marketing"], ["Mayor", "Mayor"], ["Member", "Member"], ["Member/President", "Member/President"], ["Membership - VP", "Membership - VP"], 
    ["Minister", "Minister"], ["Mother/Daughter", "Mother/Daughter"], ["Mortgage Specialists", "Mortgage Specialists"], ["Mother/Son", "Mother/Son"], 
    ["National Director", "National Director"], ["Nephew/Uncle", "Nephew/Uncle"], ["Niece/Aunt", "Niece/Aunt"], ["Notary Service", "Notary Service"], 
    ["Office Help", "Office Help"], ["Office Manager", "Office Manager"], ["Officials", "Officials"], ["Operating Manager", "Operating Manager"], ["Organizer", "Organizer"], 
    ["Owner", "Owner"], ["Owner/Developer", "Owner/Developer"], ["Paralegal", "Paralegal"], ["Parent", "Parent"], ["Partner", "Partner"], ["Personal Representative", "Personal Representative"], 
    ["Pilot", "Pilot"], ["President", "President"], ["President-elect", "President-elect"], ["PRINCIPAL", "PRINCIPAL"], ["Processor", "Processor"], 
    ["Program Specialist", "Program Specialist"], ["Project Engineer", "Project Engineer"], ["Project Manager", "Project Manager"], ["Public Services Director", "Public Services Director"], 
    ["QC Officer", "QC Officer"], ["Realtor", "Realtor"], ["Recorder", "Recorder"], ["Recreation Manager", "Recreation Manager"], ["Regional Counsel", "Regional Counsel"], 
    ["Registered Agent", "Registered Agent"], ["Relationship Manager", "Relationship Manager"], ["Relative - Lender", "Relative - Lender"], ["Relative-deceased", "Relative-deceased"], 
    ["Representative", "Representative"], ["Resident Agent", "Resident Agent"], ["Residential Lending Specialist", "Residential Lending Specialist"], 
    ["RESPA Enforcement Officer", "RESPA Enforcement Officer"], ["Sales/Marketing", "Sales/Marketing"], ["Same Person", "Same Person"], ["Searcher", "Searcher"], 
    ["SEC. CO-TRUSTEE", "SEC. CO-TRUSTEE"], ["Secretary", "Secretary"], ["Secretary/Treasurer", "Secretary/Treasurer"], ["Senior Vice-President", "Senior Vice-President"], 
    ["Sibling", "Sibling"], ["Significant other", "Significant other"], ["SISTER", "SISTER"], ["Sister Company", "Sister Company"], ["Sister-in-law", "Sister-in-law"], ["Son", "Son"], 
    ["Son-in-law", "Son-in-law"], ["Son/Father", "Son/Father"], ["Son/Mother", "Son/Mother"], ["Spouse", "Spouse"], ["SR. Vice President", "SR. Vice President"], 
    ["Step-Father", "Step-Father"], ["Sub Contractor", "Sub Contractor"], ["Subordinations", "Subordinations"], ["Successor Trustee", "Successor Trustee"], 
    ["Transaction Coordinator", "Transaction Coordinator"], ["Treasurer", "Treasurer"], ["TRUST", "TRUST"], ["Trustee", "Trustee"], ["Trustee,As General Partner", "Trustee,As General Partner"], 
    ["Trustee/Spouse", "Trustee/Spouse"], ["Uncle", "Uncle"], ["Vice-President", "Vice-President"]]

    return options, collection

    # options = "Accomodator
    #   Account Rep
    #   Accountant
    #   Accounts Payable
    #   Administrator
    #   Advisor
    #   Agency
    #   Agent
    #   Appraiser
    #   Assistant
    #   Asst. Manager
    #   Asst. Director
    #   Attorney
    #   Attorney-In-Fact
    #   Auditor
    #   Aunt/Nephew
    #   Authorized Agent
    #   Authorized Signer
    #   Board Member
    #   Book Keeper
    #   Branch Manager
    #   Bro/Sis
    #   Broker
    #   Brother
    #   Brother-In-law
    #   Builder
    #   Business
    #   Business Partner
    #   Co-Trustee
    #   CEO
    #   CFO
    #   Chairman
    #   Chairman of Board
    #   Chief Financial Officer
    #   Chief Operating Officer
    #   City Clerk/Recorder
    #   City Manager
    #   Claims
    #   Claims Counsel
    #   Claims Representative
    #   Client
    #   Closer
    #   Closing Agent Help
    #   Closing Coordinator
    #   CO - Officer
    #   CO-Trustee
    #   CO-Personal Representative
    #   Co-Worker
    #   Coach
    #   Commercial Loan Officer
    #   Commission Chair
    #   Commission Liason
    #   Commissioner
    #   Community Manager
    #   Companion
    #   Company
    #   Contact Person
    #   Controller
    #   Council
    #   Council Member
    #   Counsel
    #   County Manager
    #   CPL
    #   Cross Reference
    #   Custodian FBO
    #   Daughter
    #   Daughter / Mother
    #   Daughter/Father
    #   DBA
    #   Deceased Spouse
    #   Developer
    #   Development
    #   Developmental Services
    #   Director
    #   Director of Sales
    #   Divorced
    #   Doc Specialist
    #   Economic Development
    #   ED Chair
    #   Employee
    #   Employer
    #   Engineer
    #   Escrow
    #   Escrow Assistant
    #   Escrow Coordinator
    #   Escrow Officer
    #   Ex-Spouse
    #   Examiner
    #   Exchange Specialist
    #   Exec. Director
    #   Executive Vice President
    #   Executor
    #   Family
    #   Father
    #   Father-in-law
    #   Father/Daughter
    #   Father/Son
    #   Fiance
    #   Finance Manager
    #   Finance Officer
    #   Financial
    #   Financial Advisor
    #   FKA
    #   For Payoffs
    #   Friend
    #   General Manager
    #   General Partner
    #   General Personal Representative
    #   Boyfriend/Girlfriend
    #   Good Friend
    #   Granddaughter
    #   Grandmother
    #   Grandson
    #   Grantor
    #   HOA
    #   HOA Contact
    #   HOA Handler
    #   HOA Manager
    #   HOA President
    #   HOA Secretary
    #   Human Resources
    #   Husband/Wife
    #   In-Laws
    #   IRA
    #   Law Firm
    #   Legal Assistant
    #   Legal/Bond
    #   LENDER
    #   Limited Partner
    #   Loan Officer
    #   Loan Processor
    #   Lobbyist
    #   Manager
    #   Manager/Member
    #   Managing General Partner
    #   Managing Member
    #   Managing Partner
    #   Marketing
    #   Mayor
    #   Member
    #   Member/President
    #   Membership - VP
    #   Minister
    #   Mother/Daughter
    #   Mortgage Specialists
    #   Mother/Son
    #   National Director
    #   Nephew/Uncle
    #   Niece/Aunt
    #   Notary Service
    #   Office Help
    #   Office Manager
    #   Officials
    #   Operating Manager
    #   Organizer
    #   Owner
    #   Owner/Developer
    #   Paralegal
    #   Parent
    #   Partner
    #   Personal Representative
    #   Pilot
    #   President
    #   President-elect
    #   PRINCIPAL
    #   Processor
    #   Program Specialist
    #   Project Engineer
    #   Project Manager
    #   Public Services Director
    #   QC Officer
    #   Realtor
    #   Recorder
    #   Recreation Manager
    #   Regional Counsel
    #   Registered Agent
    #   Relationship Manager
    #   Relative - Lender
    #   Relative-deceased
    #   Representative
    #   Resident Agent
    #   Residential Lending Specialist
    #   RESPA Enforcement Officer
    #   Sales/Marketing
    #   Same Person
    #   Searcher
    #   SEC. CO-TRUSTEE
    #   Secretary
    #   Secretary/Treasurer
    #   Senior Vice-President
    #   Sibling
    #   Significant other
    #   SISTER
    #   Sister Company
    #   Sister-in-law
    #   Son
    #   Son-in-law
    #   Son/Father
    #   Son/Mother
    #   Spouse
    #   SR. Vice President
    #   Step-Father
    #   Sub Contractor
    #   Subordinations
    #   Successor Trustee
    #   Transaction Coordinator
    #   Treasurer
    #   TRUST
    #   Trustee
    #   Trustee,As General Partner
    #   Trustee/Spouse
    #   Uncle
    #   Vice-President
    #   "
    # options.split("\n").each do |s|
    #   s = s.strip
    #   collection << [s, s]
    # end
  end
end