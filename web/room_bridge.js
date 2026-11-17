// The page side of the online room (scripts/net/transport_web.gd): Firebase Realtime Database behind one object, FPRoom.
// Godot calls its functions with JavaScriptBridge.eval and reads FPRoom.pull(), a queue of JSON messages.
// The web config below is public by design (Firebase web apps carry it in the page); access is limited by database.rules.json.
// Open the page with ?emulator=localhost:9000 to talk to the local Realtime Database emulator instead.
// Godot's web export only copies index.html, so web/build_head.py puts this file inside export_presets.cfg (html/head_include).
(function () {
  const config = {
    apiKey: "AIzaSyDLuFBV-zwBZNhrXWR_QjhHSC1pU-ZaP38",
    authDomain: "aklabs-dev.firebaseapp.com",
    databaseURL: "https://aklabs-dev-default-rtdb.firebaseio.com",
    projectId: "aklabs-dev",
    storageBucket: "aklabs-dev.firebasestorage.app",
    messagingSenderId: "11340527725",
    appId: "1:11340527725:web:fbce772041e1731c37e764"
  };
  const queue = [];
  let db = null;
  const subs = [];
  function push(m) { queue.push(JSON.stringify(m)); }
  function fail(e) { push({ t: "error", text: String((e && e.message) || e) }); }
  function room(code) { return db.ref("rooms/" + code); }
  function member(code, pid, name) {
    const ref = room(code).child("members/" + pid);
    ref.onDisconnect().remove();
    return ref.set({ name: String(name).slice(0, 24), seen: Date.now() });
  }
  function unsub() { while (subs.length) { try { subs.pop()(); } catch (e) {} } }

  window.FPRoom = {
    // True when the Firebase scripts loaded and the database object exists.
    ready: function () {
      try {
        if (typeof firebase === "undefined") return false;
        if (!db) {
          firebase.initializeApp(config);
          db = firebase.database();
          const em = new URLSearchParams(location.search).get("emulator");
          if (em) { const p = em.split(":"); db.useEmulator(p[0], parseInt(p[1] || "9000", 10)); }
        }
        return true;
      } catch (e) { return false; }
    },
    // The messages for Godot since the last call, as a JSON array of JSON strings.
    pull: function () { const s = JSON.stringify(queue); queue.length = 0; return s; },
    // Creates room `code` if it is free (a transaction), then listens for guests' ops and for who is in the room.
    create: function (code, pid, name, state) {
      room(code).transaction(function (cur) {
        return cur === null ? { host: pid, created: Date.now(), state: state } : undefined;
      }, function (err, committed) {
        if (err) return fail(err);
        if (!committed) return push({ t: "taken" });
        member(code, pid, name).then(function () {
          const ops = room(code).child("ops");
          const onOp = ops.on("child_added", function (snap) {
            const v = snap.val();
            if (v && typeof v.j === "string") push({ t: "op", o: v.j });
            snap.ref.remove();
          });
          const mem = room(code).child("members");
          const onMem = mem.on("value", function (snap) {
            const m = {};
            snap.forEach(function (c) { m[c.key] = (c.val() || {}).name || ""; });
            push({ t: "members", m: m });
          });
          subs.push(function () { ops.off("child_added", onOp); mem.off("value", onMem); });
          push({ t: "created" });
        }).catch(fail);
      }, false);
    },
    // Joins an existing room and mirrors its state.
    join: function (code, pid, name) {
      room(code).child("state").get().then(function (snap) {
        if (!snap.exists()) return push({ t: "nosuch" });
        return member(code, pid, name).then(function () {
          const st = room(code).child("state");
          let first = true;
          const on = st.on("value", function (s) {
            if (s.exists()) push({ t: "state", s: s.val() });
            if (first) { first = false; push({ t: "joined" }); }
          });
          subs.push(function () { st.off("value", on); });
        });
      }).catch(fail);
    },
    // A guest's op, for the host.
    send_op: function (code, pid, op) {
      room(code).child("ops").push({ by: pid, j: op, t: Date.now() }).catch(fail);
    },
    // The host's new state, for the guests.
    publish: function (code, state) { room(code).child("state").set(state).catch(fail); },
    leave: function (code, pid) {
      unsub();
      room(code).child("members/" + pid).remove().catch(function () {});
    }
  };
})();
