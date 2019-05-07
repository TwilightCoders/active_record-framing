class Admin < User

  default_scope {
    # select(arel_table[Arel.star], arel_table[:tableoid])#
    select(arel_table[:id], arel_table[:kind]).where(kind: 1)
  }

  frame :deleted, -> { where(arel_table[:deleted_at].not_eq(nil)) }
  frame :all, -> { }
  frame :present, -> { where(arel_table[:deleted_at].eq(nil)) }

  default_frame {
    present
  }

end
