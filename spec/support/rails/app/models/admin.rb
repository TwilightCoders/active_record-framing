class Admin < User

  self.default_frames = []

  def self.default_frame
    unscoped.where(arel_table[:kind].eq(2))
  end

  # default_scope {
  #   select(arel_table[:id], arel_table[:kind], arel_table[:type]).where(kind: 2)
  # }

  def self.default_scope
    select(arel_table[:id], arel_table[:kind], arel_table[:type]).where(kind: 2)
  end

  frame :special, -> {
    where(arel_table[:email].eq('special.person@example.com'))
  }

end
