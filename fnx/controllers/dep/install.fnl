(local sn (require :supernova))

(local port/shell-out (require :fnx.ports.out.shell))

(local component/io (require :fnx.components.io))

(local controller/dependencies (require :fnx.controllers.dep.dependencies))
(local controller/fnx (require :fnx.controllers.dep.install.fnx))
(local controller/rock (require :fnx.controllers.dep.install.rock))

(local helper/list (require :fnx.helpers.list))
(local helper/path (require :fnx.helpers.path))

(local logic/dependencies (require :fnx.logic.dependencies))
(local logic/list (require :fnx.logic.dep.list))
(local logic/smk (require :fnx.logic.smk))
(local logic/version (require :fnx.logic.version))

(local model/xpackage (require :fnx.models.xpackage))

(local controller {})

(fn controller.handle! [arguments]
  (let [{:core-fnx core-fnx
         :to-list       to-list
         :installable   installable
         :not-installed    not-installed}
          (controller/dependencies.load-data! arguments)]

    (port/shell-out.dispatch!
      [[:line  (logic/version.display core-fnx.version)]
       [:line  ""]
       [:table (logic/list.build-sml-table to-list)]
       [:line  ""]])

    (local cyclic-control {:_any? false})

    (controller.install! not-installed cyclic-control arguments)

    (var keep-installing true)
    (var protection 1000)

    (while (and keep-installing (> protection 0))
      (set protection (- protection 1))
      (let [working-directory (component/io.current-directory)
            main-dot-fnx-path (.. working-directory "/.fnx.fnl")
            candidates        (. (controller/dependencies.build-from main-dot-fnx-path) :candidates)
            state             (controller/dependencies.retrieve-state! candidates arguments)
            to-install
            (if (or (. arguments.present :--force) (. arguments.present :-f))
              candidates
              (logic/list.not-installed candidates state))]

          (controller.install! to-install cyclic-control arguments)

          (local
            new-ones
            (. (controller/dependencies.build-from main-dot-fnx-path) :candidates))

          (if (> (length new-ones) (length candidates))
            (set keep-installing true)
            (set keep-installing false))))

    (if cyclic-control._any?
      (port/shell-out.dispatch!
         (logic/smk.line (.. "\n" (sn.green "Finished!")))))))

(fn controller.install! [dependencies cyclic-control arguments]
  (each [_ dependency (pairs dependencies)]
    (match [dependency.language dependency.provider]
      [:fennel :fnx]  (controller/fnx.install dependency cyclic-control arguments)
      [:lua    :rock] (controller/rock.install dependency cyclic-control arguments)
      _
        (port/shell-out.dispatch!
          (logic/smk.line
            (.. "Sorry. I don't know how to install: "
                (sn.red dependency.identifier)))))))

controller
