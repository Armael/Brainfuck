Require Import bf.
Require Import Lists.Streams.
Require Import Arith.Minus.

Definition option_bind {A B : Set} (f : A -> option B) (x : option A) : option B :=
  match x with
    | None => None
    | Some a => f a
  end.

Definition conf := (Instr.instruction, state).

Inductive iter : (Instr.instruction * state) -> (Instr.instruction * state) -> Prop :=
| iter_idem : forall conf : (Instr.instruction * state), iter conf conf
| iter_step : forall conf conf' conf'' : (Instr.instruction * state),
                step conf = Some conf' ->
                iter conf' conf'' ->
                iter conf conf''.

Open Scope state_scope.

Theorem left_right : forall m c,  iter (< > c, m) (c, m).
Proof.
  intros.
  destruct m as [[l ls] curr rs stdin stdout].
  apply (iter_step _ (> c, (state[ ls, l, Cons curr rs, stdin, stdout ])) _).
  reflexivity.
  
  apply (iter_step _ (c, (state[ Cons l ls, curr, rs, stdin, stdout ])) _).
  reflexivity.
  
  apply iter_idem.
Qed.

(* Basically an evaluation function *)

Ltac do_step :=
  simpl;
  match goal with
    | [ |- iter ?C ?C] =>
      apply iter_idem
    | [ |- iter (< ?C, state[Cons ?l ?ls, ?curr, ?rs, ?stdin, ?stdout]) _] =>
      apply (iter_step _ (C, state[ls, l, Cons curr rs, stdin, stdout]));
        [reflexivity|]
    | [ |- iter (> ?C, state[?ls, ?curr, Cons ?r ?rs, ?stdin, ?stdout]) _] =>
      apply (iter_step _ (C, state[Cons curr ls, r, rs, stdin, stdout]));
        [reflexivity|]
    | [ |- iter (+ ?C, state[?ls, ?curr, ?rs, ?stdin, ?stdout]) _] =>
      apply (iter_step _ (C, state[ls, S curr, rs, stdin, stdout]));
        [reflexivity|]
    | [ |- iter (- ?C, state[?ls, 0, ?rs, ?stdin, ?stdout]) _] =>
      apply (iter_step _ (C, state[ls, 0, rs, stdin, stdout]));
        [reflexivity|]
    | [ |- iter (- ?C, state[?ls, S ?curr, ?rs, ?stdin, ?stdout]) _] =>
      apply (iter_step _ (C, state[ls, curr, rs, stdin, stdout]));
        [reflexivity|]
    | [ |- iter (i ?C, state[?ls, _, ?rs, Cons ?input ?stdin, ?stdout]) _] =>
      apply (iter_step _ (C, state[ls, input, rs, stdin, stdout]));
        [reflexivity|]
    | [ |- iter (o ?C, state[?ls, ?curr, ?rs, ?stdin, ?stdout]) _] =>
      apply (iter_step _ (C, state[ls, curr, rs, stdin, curr :: stdout]));
        [reflexivity|]
    | [ |- iter ([ ?b ] ?C, state[?ls, S ?n, ?rs, ?stdin, ?stdout]) _ ] =>
      apply (iter_step _ (sequence b ([ b ]C), state[ls, S n, rs, stdin, stdout]));
        [reflexivity|]
    | [ |- iter ([ ?b ] ?C, state[?ls, 0, ?rs, ?stdin, ?stdout]) _ ] =>
      apply (iter_step _ (C, state[ls, 0, rs, stdin, stdout]));
        [reflexivity|]
  end.

Ltac do_destruct :=
  simpl;
  match goal with
    | [ |- iter (< ?C, ?M) _] =>
      destruct M as [[?l ?ls] ?curr ?rs ?stdin ?stdout]
    | [ |- iter (> ?C, ?M) _] =>
      destruct M as [?ls ?curr [?r ?rs] ?stdin ?stdout]
    | [ |- iter (+ ?C, ?M) _] =>
      destruct M as [?ls ?curr ?rs ?stdin ?stdout]
  end.
      

Module BF_Automation_Tests.
Theorem left_right' : forall m c,  iter (< > c, m) (c, m).
Proof.
  intros.
  repeat (do_step || do_destruct).
Qed.

Theorem plus_minus : forall m c, iter (+ - c, m) (c, m).
Proof.
  intros.
  repeat (do_step || do_destruct).
Qed.

Theorem minus_minus : forall ls n rs stdin stdout c,
                        iter (- c, state[ls, n, rs, stdin, stdout])
                             (c, state[ls, minus n 1, rs, stdin, stdout]).
Proof.
  intros.
  destruct n; repeat do_step.
  rewrite <- minus_n_O.
  do_step.
Qed.

Theorem input : forall ls n rs input stdin stdout c,
                  iter (i c, state[ls, n, rs, Cons input stdin, stdout])
                       (c, state[ls, input, rs, stdin, stdout]).
Proof.
  intros.
  repeat do_step.
Qed.

Theorem output : forall ls n rs stdin stdout c,
                   iter (o c, state[ls, n, rs, stdin, stdout])
                        (c, state[ls, n, rs, stdin, n :: stdout]).
Proof.
  intros.
  repeat do_step.
Qed.

Theorem loop : forall ls rs stdin stdout c,
                 iter ([-END] c, state[ls, 5, rs, stdin, stdout])
                      (c, state[ls, 0, rs, stdin, stdout]).
Proof.
  intros.
  repeat do_step.
Qed.

Theorem nonloop : forall ls rs stdin stdout b c,
                    iter ([b]c, state[ls, 0, rs, stdin, stdout])
                         (c, state[ls, 0, rs, stdin, stdout]).
Proof.
  intros.
  repeat do_step.
Qed.

Theorem non_termination : forall ls rs stdin stdout c,
                           iter ([END]c, state[ls, 1, rs, stdin, stdout])
                                (c, state[ls, 1, rs, stdin, stdout]).
Proof.
  intros.
  (* For some reason this does terminate (although it doesn't really
  change the goal *)

  repeat do_step.
Abort.

Definition hello_world := 
  + + + + + + + + + + [ > + + + + + + + > + + + + + + + + + + > + + +
  > + < < < < - END ] > + + o > + o + + + + + + + o o + + + o > + + o
  < < + + + + + + + + + + + + + + + o > o + + + o - - - - - - o - - -
  - - - - - o > + o > o END.

Open Scope list_scope. (* wut *)
Definition hello_world_string := 10 :: 33::100::108::114::111::87::32::111::108::108::101::72::nil.

Definition eight_unfolded_zeroes :=
Cons 0 (Cons 0 (Cons 0 (Cons 0 (Cons 0 (Cons 0 (Cons 0 (Cons 0 zeroes))))))).

Theorem hello_world_works :
  exists ls n rs,
  iter (hello_world, state[zeroes, 0, eight_unfolded_zeroes, zeroes, nil])
       (END, state[
                 ls,
                 n,
                 rs,
                 zeroes,
                 hello_world_string]).
Proof.
  (* Unfortunately, we have to guess the state of the resulting
  stack. *)
  exists (Cons 33 (Cons 100 (Cons 87 (Cons 0 zeroes)))).
  exists 10.
  exists (Cons 0 (Cons 0 (Cons 0 (Cons 0 (cofix zeroes : Stream nat := Cons 0 zeroes))))).
  unfold  hello_world.
  unfold init.
  unfold eight_unfolded_zeroes.
  unfold hello_world_string.
  
  repeat do_step.
  fold zeroes.
  apply iter_idem.
Qed.

End BF_Automation_Tests.