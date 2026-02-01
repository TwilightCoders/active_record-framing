class Admin < User

  # Inherit User's default_frame - don't override
  # This tests that STI child classes properly inherit parent frames

  def self.default_scope
    select(arel_table[:id], arel_table[:kind], arel_table[:type]).where(kind: 2)
  end

  frame :special, -> {
    where(arel_table[:email].eq('special.person@example.com'))
  }

end
