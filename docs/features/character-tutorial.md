# Character tutorial

Status: working for the classic chains. New characters spawn on their job's
tutorial start field (from the job table projection), the client's
`REQUEST_TUTORIAL_ITEM` grants the job's starter items idempotently (level-1
characters on the start field only, topping up what is not held), walking out
of the start field at level 1 grants the tutorial rewards and unlocks the
tutorial's maps and taxis (persisted, with taxi-discover packets), the
tutorial skip item teleports to the skip destination when used on the start
field, and guide-pop-up progress (`GuideRecord`) is persisted and replayed on
field enter.

The classic chain (start field → job training yard) runs on the
trigger-script runtime: the barrier monster gate, the carry quest (liftable
pickup/install firing the item_move condition), job-portal selection, and
the map-exit teleport all play through the xblock scripts.

## Still missing

- verification of the newer-class scripted chains (walk-and-talk states,
  movies, npc choreography, quest-state gates). The runtime runs on every
  scripted map and warns on unimplemented actions, so each chain's remaining
  coverage surfaces during a test run
