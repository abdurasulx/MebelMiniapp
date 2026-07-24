import { useEffect, useImperativeHandle, useRef, forwardRef } from "react";
import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { TransformControls } from "three/examples/jsm/controls/TransformControls.js";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";

/**
 * Bazis uslubidagi xona-kompozitor sahnasi — bir nechta GLB elementni bitta
 * Three.js sahnaga yuklaydi, har biri o'zining saqlangan
 * position/rotation/scale'ida joylashadi. `editable` bo'lsa bosib tanlash,
 * sudrab ko'chirish/aylantirish (TransformControls), o'lchash va eshik-ochish
 * animatsiyasini bosib ishga tushirish ishlaydi.
 *
 * Imperative API (`ref`): `screenshot()`, `setTransformMode(mode)`,
 * `setMeasureMode(bool)`, `deleteSelected()`.
 */
const RoomScene = forwardRef(function RoomScene(
  { items, editable = false, onSelect, onTransformChange, onMeasure },
  ref
) {
  const mountRef = useRef(null);
  const stateRef = useRef({});

  useImperativeHandle(ref, () => ({
    screenshot() {
      const { renderer, scene, camera } = stateRef.current;
      if (!renderer) return null;
      renderer.render(scene, camera);
      return renderer.domElement.toDataURL("image/png");
    },
    setTransformMode(mode) {
      stateRef.current.transformControls?.setMode(mode);
    },
    setMeasureMode(on) {
      stateRef.current.measureMode = on;
      if (!on) stateRef.current.measurePoints = [];
    },
    deselect() {
      stateRef.current.transformControls?.detach();
    },
  }));

  // Sahna bir marta quriladi — item ro'yxati o'zgarganda diff qilib
  // yuklanadi/olib tashlanadi (pastdagi alohida effektda).
  useEffect(() => {
    const mount = mountRef.current;
    if (!mount) return;

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0xeef1f5);

    const camera = new THREE.PerspectiveCamera(50, mount.clientWidth / mount.clientHeight, 0.1, 100);
    camera.position.set(4, 3.2, 5);

    const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    renderer.setSize(mount.clientWidth, mount.clientHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.shadowMap.enabled = true;
    mount.appendChild(renderer.domElement);

    const hemi = new THREE.HemisphereLight(0xffffff, 0x444444, 1.2);
    scene.add(hemi);
    const dir = new THREE.DirectionalLight(0xffffff, 1.4);
    dir.position.set(5, 8, 4);
    dir.castShadow = true;
    scene.add(dir);

    const floor = new THREE.Mesh(
      new THREE.PlaneGeometry(20, 20),
      new THREE.MeshStandardMaterial({ color: 0xd8d2c8 })
    );
    floor.rotation.x = -Math.PI / 2;
    floor.receiveShadow = true;
    scene.add(floor);
    scene.add(new THREE.GridHelper(20, 40, 0xbbbbbb, 0xdddddd));

    const controls = new OrbitControls(camera, renderer.domElement);
    controls.target.set(0, 1, 0);
    controls.enableDamping = true;

    const transformControls = new TransformControls(camera, renderer.domElement);
    transformControls.addEventListener("dragging-changed", (e) => {
      controls.enabled = !e.value;
    });
    transformControls.addEventListener("objectChange", () => {
      const obj = transformControls.object;
      if (!obj) return;
      onTransformChange?.(obj.userData.itemId, {
        position: obj.position.toArray(),
        rotation: [obj.rotation.x, obj.rotation.y, obj.rotation.z],
        scale: obj.scale.toArray(),
      });
    });
    scene.add(transformControls.getHelper());

    const raycaster = new THREE.Raycaster();
    const pointer = new THREE.Vector2();
    const measureMarkers = new THREE.Group();
    scene.add(measureMarkers);

    function handleClick(event) {
      const rect = renderer.domElement.getBoundingClientRect();
      pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
      pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
      raycaster.setFromCamera(pointer, camera);
      const meshes = [];
      scene.traverse((o) => {
        if (o.isMesh && o !== floor) meshes.push(o);
      });
      const hits = raycaster.intersectObjects(meshes, false);
      if (!hits.length) return;
      const hit = hits[0];

      if (stateRef.current.measureMode) {
        measureMarkers.clear();
        const pts = stateRef.current.measurePoints || [];
        pts.push(hit.point.clone());
        stateRef.current.measurePoints = pts;
        pts.forEach((p) => {
          const dot = new THREE.Mesh(
            new THREE.SphereGeometry(0.04, 12, 12),
            new THREE.MeshBasicMaterial({ color: 0xff5555 })
          );
          dot.position.copy(p);
          measureMarkers.add(dot);
        });
        if (pts.length === 2) {
          const line = new THREE.Line(
            new THREE.BufferGeometry().setFromPoints(pts),
            new THREE.LineBasicMaterial({ color: 0xff5555 })
          );
          measureMarkers.add(line);
          onMeasure?.(pts[0].distanceTo(pts[1]));
          stateRef.current.measurePoints = [];
        }
        return;
      }

      // Yuqoriga ko'tarilib, shu mesh qaysi yuklangan itemga tegishli ekanini topamiz.
      let node = hit.object;
      let itemRoot = null;
      while (node) {
        if (node.userData?.itemId) {
          itemRoot = node;
          break;
        }
        node = node.parent;
      }
      if (!itemRoot) return;

      // Eshik/tortma animatsiyasi: bosilgan meshning nomi bilan mos keladigan
      // animatsiya klipi bo'lsa (eksport konvensiyasi), shuni ishga tushirib/
      // teskari aylantiramiz.
      const mixerInfo = itemRoot.userData.mixerInfo;
      if (mixerInfo) {
        const clip = mixerInfo.clips.find(
          (c) => c.name === hit.object.name || hit.object.name.includes(c.name) || c.name.includes(hit.object.name)
        );
        if (clip) {
          const action = mixerInfo.mixer.clipAction(clip);
          const reverse = action.paused && action.time > 0;
          action.paused = false;
          action.clampWhenFinished = true;
          action.loop = THREE.LoopOnce;
          action.timeScale = reverse ? -1 : 1;
          if (reverse) action.time = action.getClip().duration;
          action.play();
          return;
        }
      }

      if (editable) {
        transformControls.attach(itemRoot);
      }
      onSelect?.(itemRoot.userData.itemId);
    }
    renderer.domElement.addEventListener("click", handleClick);

    const clock = new THREE.Clock();
    let raf;
    function animate() {
      raf = requestAnimationFrame(animate);
      const dt = clock.getDelta();
      scene.traverse((o) => {
        if (o.userData?.mixerInfo) o.userData.mixerInfo.mixer.update(dt);
      });
      controls.update();
      renderer.render(scene, camera);
    }
    animate();

    function handleResize() {
      if (!mount) return;
      camera.aspect = mount.clientWidth / mount.clientHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(mount.clientWidth, mount.clientHeight);
    }
    window.addEventListener("resize", handleResize);

    stateRef.current = {
      scene, camera, renderer, controls, transformControls,
      loadedItems: new Map(), measureMode: false, measurePoints: [],
    };

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", handleResize);
      renderer.domElement.removeEventListener("click", handleClick);
      controls.dispose();
      transformControls.dispose();
      renderer.dispose();
      mount.removeChild(renderer.domElement);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Itemlar ro'yxati o'zgarganda: yangilarini yuklaymiz, olib tashlanganlarini o'chiramiz.
  useEffect(() => {
    const st = stateRef.current;
    if (!st.scene) return;
    const loader = new GLTFLoader();
    const currentIds = new Set(items.map((i) => i.id));

    for (const [id, group] of st.loadedItems) {
      if (!currentIds.has(id)) {
        st.scene.remove(group);
        st.loadedItems.delete(id);
      }
    }

    for (const item of items) {
      if (st.loadedItems.has(item.id) || !item.glb_url) continue;
      loader.load(item.glb_url, (gltf) => {
        const root = gltf.scene;
        root.userData.itemId = item.id;
        root.position.fromArray(item.position || [0, 0, 0]);
        root.rotation.fromArray(item.rotation || [0, 0, 0]);
        root.scale.fromArray(item.scale || [1, 1, 1]);
        root.traverse((o) => {
          if (o.isMesh) {
            o.castShadow = true;
            o.receiveShadow = true;
            if (item.color_hex && o.material?.color) {
              o.material = o.material.clone();
              o.material.color.set(item.color_hex);
            }
          }
        });
        if (gltf.animations?.length) {
          const mixer = new THREE.AnimationMixer(root);
          root.userData.mixerInfo = { mixer, clips: gltf.animations };
        }
        st.scene.add(root);
        st.loadedItems.set(item.id, root);
      });
    }
  }, [items]);

  return <div ref={mountRef} style={{ width: "100%", height: "100%" }} />;
});

export default RoomScene;
