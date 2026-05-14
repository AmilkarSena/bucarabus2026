import { io } from "socket.io-client";

const apiBase = process.env.WS_BASE || "http://localhost:3001";
const token = process.env.TEST_JWT;

function connectAnon() {
  return new Promise((resolve) => {
    const socket = io(apiBase, { transports: ["websocket", "polling"] });
    socket.on("connect", () => {
      console.log("ANON connected", socket.id);
      socket.emit("get-all-locations");
      socket.on("all-locations", (data) => {
        console.log("ANON all-locations count", Array.isArray(data) ? data.length : "n/a");
        socket.disconnect();
        resolve();
      });
    });
    socket.on("connect_error", (err) => {
      console.log("ANON connect_error", err?.message);
      resolve();
    });
  });
}

function connectAuth() {
  return new Promise((resolve) => {
    const socket = io(apiBase, { transports: ["websocket", "polling"], auth: token ? { token } : {} });
    socket.on("connect", () => {
      console.log("AUTH connected", socket.id);
      const locationData = { plateNumber: "TEST-123", lat: 7.119, lng: -73.119, routeId: 1 };
      socket.emit("bus-location", locationData);
      socket.emit("bus-start-shift", { plateNumber: "TEST-123", busId: 1, driverId: 1, routeId: 1, tripId: 1 });
      socket.emit("report-incident", { incidentId: 999, tag: "test", name: "test", plateNumber: "TEST-123", lat: 7.119, lng: -73.119 });
      socket.emit("bus-end-shift", { plateNumber: "TEST-123", busId: 1, driverId: 1, tripId: 1, duration: 1, tripsCompleted: 1 });
      setTimeout(() => { socket.disconnect(); resolve(); }, 1000);
    });
    socket.on("auth-error", (data) => {
      console.log("AUTH auth-error", data?.message);
    });
    socket.on("connect_error", (err) => {
      console.log("AUTH connect_error", err?.message);
      resolve();
    });
  });
}

await connectAnon();
await connectAuth();
