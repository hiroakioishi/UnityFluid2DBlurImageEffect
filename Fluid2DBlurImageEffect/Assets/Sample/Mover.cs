using UnityEngine;
using System.Collections;

public class Mover : MonoBehaviour {

	void Start () {
	
	}
	
	void Update () {

		transform.RotateAround (Vector3.zero, Vector3.forward, Time.deltaTime * 200.0f);

	}
}
