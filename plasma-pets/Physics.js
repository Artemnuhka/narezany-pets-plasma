.pragma library

// A pose is sampled in seven vertical slices. Both physics and pointer regions
// use these slices after reflection, rotation and compression around the relevant pivot.
function hull(pose, width, height, mirrored, sx, sy, degrees, pivotX, pivotY) {
    const parts = []
    const angle = degrees * Math.PI / 180
    const cs = Math.cos(angle), sn = Math.sin(angle)
    const cx = width / 2
    const px = pivotX ?? cx
    const py = pivotY ?? height
    let left = Infinity, right = -Infinity, top = Infinity, bottom = -Infinity
    for (let i = 1; i < pose.length; i += 4) {
        const halfW = (pose[i+2] - pose[i]) * sx / 2
        const halfH = (pose[i+3] - pose[i+1]) * sy / 2
        const dx = cx - px + ((pose[i]+pose[i+2])/2 - cx) * sx * (mirrored ? -1 : 1)
        const dy = height - py + ((pose[i+1]+pose[i+3])/2 - height) * sy
        const x = px + dx * cs - dy * sn, y = py + dx * sn + dy * cs
        const w = Math.abs(halfW*cs) + Math.abs(halfH*sn)
        const h = Math.abs(halfH*cs) + Math.abs(halfW*sn)
        const part = {l:x-w, r:x+w, t:y-h, b:y+h}
        parts.push(part)
        left = Math.min(left,part.l); right = Math.max(right,part.r)
        top = Math.min(top,part.t); bottom = Math.max(bottom,part.b)
    }
    return {parts:parts,l:left,r:right,t:top,b:bottom}
}

// Return the signed gap to the first touching pair of slices. A negative
// value means the current outlines intersect, e.g. when a pose gets wider.
function gap(a, b, horizontal, direction) {
    const n = horizontal ? "l" : "t", f = horizontal ? "r" : "b"
    const cn = horizontal ? "t" : "l", cf = horizontal ? "b" : "r"
    const cross = horizontal ? b.y-a.y : b.x-a.x
    const along = horizontal ? b.x-a.x : b.y-a.y
    if (a.body[cf] <= cross+b.body[cn]+0.01 || a.body[cn] >= cross+b.body[cf]-0.01) return Infinity
    let nearest = Infinity
    for (const p of a.body.parts) for (const q of b.body.parts) {
        if (p[cf] <= cross+q[cn]+0.01 || p[cn] >= cross+q[cf]-0.01) continue
        const distance = direction > 0 ? along+q[n]-p[f] : p[n]-along-q[f]
        nearest = Math.min(nearest, distance)
    }
    return nearest
}

function sweep(p, peers, horizontal, delta, arena) {
    const direction = Math.sign(delta)
    const wall = horizontal ? (direction > 0 ? arena.width-p.x-p.body.r : p.x+p.body.l)
                            : (direction > 0 ? arena.height-p.y-p.body.b : p.y+p.body.t)
    let travel = Math.min(Math.abs(delta), Math.max(0,wall))
    let contact = null
    for (const q of peers) {
        if (q === p || !q.visible || (horizontal && (q === p.riding || q.riding === p))) continue
        const distance = gap(p,q,horizontal,direction)
        if (distance >= -0.05 && distance <= travel + 0.005) {
            travel = Math.max(0,distance)
            contact = q
        }
    }
    if (horizontal) p.x += direction * travel
    else p.y += direction * travel
    return {blocked:contact !== null || travel < Math.abs(delta)-0.001, other:contact}
}

function move(p, peers, dx, dy, arena) {
    const steps = Math.max(1,Math.ceil(Math.max(Math.abs(dx),Math.abs(dy))/5))
    let hitX = false, hitY = false, side = null, other = null
    for (let i=0; i<steps; i++) {
        if (dx) {
            const hit = sweep(p,peers,true,dx/steps,arena)
            hitX = hitX || hit.blocked
            if (hit.other) side = hit.other
        }
        if (dy) {
            const hit = sweep(p,peers,false,dy/steps,arena)
            hitY = hitY || hit.blocked
            if (hit.other) other = hit.other
        }
    }
    return {hitX:hitX, hitY:hitY, side:side, other:other}
}

function place(p, peers, preferred, width, height) {
    const others = peers.filter(q => q !== p && q.visible)
    const xs = [preferred,-p.body.l,width-p.body.r]
    for (const q of others) xs.push(q.x+q.body.l-p.body.r, q.x+q.body.r-p.body.l)
    xs.sort((a,b) => Math.abs(a-preferred)-Math.abs(b-preferred))
    let bestY = -Infinity, bestX = preferred, support = null
    for (const x of xs) {
        if (x < -p.body.l || x > width-p.body.r) continue
        p.x = x; p.y = 0
        let y = height-p.body.b, base = null
        for (const q of others) {
            const dist = gap(p,q,false,1)
            if (dist < y) { y = dist; base = q }
        }
        if (y > bestY) { bestY = y; bestX = x; support = base }
    }
    p.x = bestX; p.y = Math.max(-p.body.t,bestY); p.riding = support
}
